{{- define "jian-bing-liu.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "jian-bing-liu.labels" -}}
app.kubernetes.io/name: {{ include "jian-bing-liu.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: jian-bing-liu
{{- end -}}

{{- define "jian-bing-liu.selectorLabels" -}}
app: web
app.kubernetes.io/name: {{ include "jian-bing-liu.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
