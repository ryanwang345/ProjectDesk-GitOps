{{- define "project-desk-e2e.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "project-desk-e2e.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 52 | trimSuffix "-" }}
{{- else if contains (include "project-desk-e2e.name" .) .Release.Name }}
{{- .Release.Name | trunc 52 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "project-desk-e2e.name" .) | trunc 52 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "project-desk-e2e.selectorLabels" -}}
app.kubernetes.io/name: {{ include "project-desk-e2e.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "project-desk-e2e.labels" -}}
{{ include "project-desk-e2e.selectorLabels" . }}
app.kubernetes.io/part-of: project-desk
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
e2e.project-desk/environment: {{ .Values.environment | quote }}
{{- end }}

{{- define "project-desk-e2e.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "project-desk-e2e.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "project-desk-e2e.image" -}}
{{- $tag := required "image.tag is required; set latest or a build number in the environment values file" .Values.image.tag | toString }}
{{- if eq $tag "main" }}
{{- fail "image.tag \"main\" is a branch name, not an image tag; use latest or a build number" }}
{{- end }}
{{- printf "%s:%s" .Values.image.repository $tag }}
{{- end }}
