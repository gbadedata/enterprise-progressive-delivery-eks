#!/usr/bin/env bash
set -euo pipefail

APP_NAMESPACE="app-dev"
APP_NAME="orders-api"
IMAGE_TAG="${IMAGE_TAG:-v1.0.0}"

ECR_REPO_URL="$(terraform -chdir=terraform/environments/dev output -raw ecr_repository_url)"
IMAGE="${ECR_REPO_URL}:${IMAGE_TAG}"

echo "Creating Argo Rollouts manifests..."
echo "Image: ${IMAGE}"

mkdir -p k8s/rollouts

cat > k8s/rollouts/namespace.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${APP_NAMESPACE}
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
EOF

cat > k8s/rollouts/serviceaccount.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${APP_NAME}
  namespace: ${APP_NAMESPACE}
automountServiceAccountToken: false
EOF

cat > k8s/rollouts/service-stable.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}-stable
  namespace: ${APP_NAMESPACE}
  labels:
    app: ${APP_NAME}
spec:
  type: ClusterIP
  selector:
    app: ${APP_NAME}
  ports:
    - name: http
      port: 80
      targetPort: 3000
EOF

cat > k8s/rollouts/service-canary.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}-canary
  namespace: ${APP_NAMESPACE}
  labels:
    app: ${APP_NAME}
spec:
  type: ClusterIP
  selector:
    app: ${APP_NAME}
  ports:
    - name: http
      port: 80
      targetPort: 3000
EOF

cat > k8s/rollouts/ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APP_NAME}
  namespace: ${APP_NAMESPACE}
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${APP_NAME}-stable
                port:
                  number: 80
EOF

cat > k8s/rollouts/analysis-template.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: ${APP_NAME}-success-rate
  namespace: ${APP_NAMESPACE}
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
  revisionHistoryLimit: 3
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
        version: v1
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
              value: "blue"
            - name: FAIL_MODE
              value: "none"
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

cat > k8s/rollouts/networkpolicy.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ${APP_NAME}-allow-ingress
  namespace: ${APP_NAMESPACE}
spec:
  podSelector:
    matchLabels:
      app: ${APP_NAME}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ingress-nginx
      ports:
        - protocol: TCP
          port: 3000
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
      ports:
        - protocol: TCP
          port: 3000
EOF

echo "Argo Rollouts manifests created in k8s/rollouts"
