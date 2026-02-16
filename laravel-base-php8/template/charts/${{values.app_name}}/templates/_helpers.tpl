{{/*
Return the base name of the chart.

IMPORTANT:
- This is derived from the Helm chart name or nameOverride.
- This is NOT the canonical service identity.
- The canonical service identity comes from `.Values.serviceName`
  (injected by Backstage).

Used for:
- Kubernetes labels
- Selector labels

NOT used for:
- Secrets
- SSM paths
*/}}
{{- define "app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{/*
Return a fully-qualified name for Kubernetes resources.

Priority:
1) .Values.fullnameOverride
2) .Release.Name

Purpose:
- Ensures uniqueness across multiple Helm releases
- Safe for use as Kubernetes resource names

NOTE:
- This is deployment-specific, not a global service identifier.
*/}}
{{- define "app.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}


{{/*
Return the chart label value (safe for Kubernetes labels).

Format:
  <chart-name>-<chart-version>

Used only for:
- Observability
- Debugging
- Tooling introspection
*/}}
{{- define "app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{/*
Common labels applied to ALL resources created by this chart.

These labels:
- Are informational
- Are safe to change
- Must NOT be relied upon for selectors

Selector labels are defined separately in `app.selectorLabels`.
*/}}
{{- define "app.labels" -}}
helm.sh/chart: {{ include "app.chart" . }}
app.kubernetes.io/name: {{ include "app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Chart.AppVersion }}
app.kubernetes.io/version: {{ . | quote }}
{{- end }}
{{- end -}}


{{/*
Selector labels (MUST remain stable).

Rules:
- MUST be a subset of pod template labels
- MUST NOT include versioned or mutable values
- MUST NOT include chart version

These labels define how Kubernetes matches Pods to Deployments.
Changing them will cause orphaned pods or failed updates.
*/}}
{{- define "app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}


{{/*
Resolve the ServiceAccount name for pods.

Behavior:
- If serviceAccount.create = true:
    - Use provided name or default to app.fullname
- If serviceAccount.create = false:
    - Use provided name or fall back to "default"

This allows platform-level control over identity.
*/}}
{{- define "app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "app.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Inject environment variables from platform-managed sources.

Order matters:
1) Bootstrap Secret
   - Allows first boot before ESO/SSM is ready
   - Contains ONLY boot-critical values (e.g. Laravel APP_KEY)
   - Optional and safe across stage and prod

2) ConfigMap
   - Non-secret application configuration

3) External Secrets Operator Secret
   - Sourced from AWS SSM
   - Overrides ConfigMap values at runtime

Notes:
- env entries have higher precedence than envFrom
- APP_KEY is intentionally pinned via bootstrap to guarantee stable encryption keys
*/}}
{{- define "app.appKeyEnv" -}}
env:
  - name: APP_KEY
    valueFrom:
      secretKeyRef:
        name: {{ include "app.fullname" . }}-bootstrap
        key: APP_KEY
        optional: true
{{- end -}}

{{- define "app.envFrom" -}}
envFrom:
  - configMapRef:
      name: {{ include "app.fullname" . }}-config
      optional: true
  - secretRef:
      name: {{ include "app.fullname" . }}-secrets
      optional: true
{{- end -}}
