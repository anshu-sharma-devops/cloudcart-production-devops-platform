{{/*
Return the chart name.
*/}}
{{- define "cloudcart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a release-specific resource name.
*/}}
{{- define "cloudcart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart name and version.
*/}}
{{- define "cloudcart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common Kubernetes labels.
*/}}
{{- define "cloudcart.labels" -}}
helm.sh/chart: {{ include "cloudcart.chart" . }}
{{ include "cloudcart.selectorLabels" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Stable labels used by Deployment and Service selectors.
The selector intentionally excludes the release name so the existing
Kustomize-managed Deployment can be migrated to Helm.
*/}}
{{- define "cloudcart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cloudcart.name" . }}
{{- end }}