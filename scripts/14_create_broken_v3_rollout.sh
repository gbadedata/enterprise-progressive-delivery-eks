#!/usr/bin/env bash
set -euo pipefail

APP_NAMESPACE="app-dev"
APP_NAME="orders-api"
IMAGE_TAG="v3.0.0"

ECR_REPO_URL="$(terraform -chdir=terraform/environments/dev output -raw ecr_repository_url)"
IMAGE="${ECR_REPO_URL}:${IMAGE_TAG}"

echo "Creating intentionally broken v3 rollout manifest..."
echo "Image: ${IMAGE}"
echo "FAIL_MODE=error"

mkdir -p k8s/rollouts

cat > k8s/rollouts/analysis-template.yaml <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: orders-api-success-rate
  namespace: app-dev
spec:
  metrics:
    - name: success-rate
      interval: 30s
      count: 2
      successCondition: len(result) > 0 && result[0] >= 0.95
      failureLimit: 1
      inconclusiveLimit: 2
      provider:
        prometheus:
          address: http://monitoring-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
          query: |
            (
              sum(rate(http_requests_total{status_code!~"5.."}[1m]))
              /
              clamp_min(sum(rate(http_requests_total[1m])), 1)
            ) or vector(1)
EOF

cat > k8s/rollouts/rollout.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: ${APP_NAME}
  namespace: ${APP_NAMESPACE}
  labels:
    app: ${APP_NAME}
spec:
  replicas: 4
  revisionHistoryLimit: 5
  selector:
    matchLabels:
      app: ${APP_NAME}
  strategy:
    canary:
      stableService: ${APP_NAME}-stable
      canaryService: ${APP_NAME}-canary
      trafficRouting:
        nginx:
          stableIngress: ${APP_NAME}
      steps:
        - setWeight: 10
        - pause:
            duration: 60s
        - analysis:
            templates:
              - templateName: ${APP_NAME}-success-rate
        - setWeight: 50
        - pause:
            duration: 60s
        - analysis:
            templates:
              - templateName: ${APP_NAME}-success-rate
        - setWeight: 100
        - pause:
            duration: 30s
  template:
    metadata:
      labels:
        app: ${APP_NAME}
        version: v3
    spec:
      serviceAccountName: ${APP_NAME}
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 100
        runAsGroup: 101
        fsGroup: 101
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: ${APP_NAME}
          image: ${IMAGE}
          imagePullPolicy: Always
          ports:
            - name: http
              containerPort: 3000
          env:
            - name: APP_VERSION
              value: "${IMAGE_TAG}"
            - name: DEPLOYMENT_COLOR
              value: "green"
            - name: FAIL_MODE
              value: "error"
            - name: PORT
              value: "3000"
          readinessProbe:
            httpGet:
              path: /ready
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /live
              port: 3000
            initialDelaySeconds: 10
            periodSeconds: 20
            timeoutSeconds: 3
            failureThreshold: 3
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "256Mi"
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: false
            capabilities:
              drop:
                - ALL
EOF

echo "Broken v3 rollout manifest created."
