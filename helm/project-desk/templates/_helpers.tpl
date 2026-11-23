{{- define "project-desk.postgresSecretName" -}}
{{- .Values.postgres.existingSecret | default "project-desk-postgres" -}}
{{- end -}}

{{- define "project-desk.aiSecretName" -}}
{{- .Values.api.ai.existingSecret | default "project-desk-ai" -}}
{{- end -}}

{{- define "project-desk.aiSecretEnabled" -}}
{{- if or .Values.api.ai.existingSecret .Values.api.ai.externalSecret.enabled .Values.api.ai.secretKey -}}true{{- end -}}
{{- end -}}

{{- define "project-desk.aiAdminTokenEnabled" -}}
{{- if or .Values.api.ai.existingSecret .Values.api.ai.externalSecret.enabled .Values.api.ai.adminToken -}}true{{- end -}}
{{- end -}}
