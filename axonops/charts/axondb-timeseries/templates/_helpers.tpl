{{/*
Expand the name of the chart.
*/}}
{{- define "axon-cassandra.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "axon-cassandra.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "axon-cassandra.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "axon-cassandra.labels" -}}
helm.sh/chart: {{ include "axon-cassandra.chart" . }}
{{ include "axon-cassandra.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "axon-cassandra.selectorLabels" -}}
app.kubernetes.io/name: {{ include "axon-cassandra.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "axon-cassandra.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "axon-cassandra.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Validate memory resources against heap size
This helper ensures that memory limits are properly configured relative to heap size
*/}}
{{- define "axon-cassandra.validateResources" -}}
{{- if and .Values.resources .Values.resources.limits .Values.resources.limits.memory .Values.heapSize }}
  {{- $heapSize := .Values.heapSize | toString }}
  {{- $memoryLimit := .Values.resources.limits.memory | toString }}
  {{- /* Convert heap size to Mi for comparison */ -}}
  {{- $heapSizeUnit := regexFind "[A-Za-z]+" $heapSize }}
  {{- $heapSizeValue := regexFind "[0-9]+" $heapSize | int64 }}
  {{- $heapSizeMi := 0 }}
  {{- if or (eq $heapSizeUnit "M") (eq $heapSizeUnit "Mi") }}
    {{- $heapSizeMi = $heapSizeValue }}
  {{- else if or (eq $heapSizeUnit "G") (eq $heapSizeUnit "Gi") }}
    {{- $heapSizeMi = mul $heapSizeValue 1024 }}
  {{- end }}
  {{- /* Convert memory limit to Mi for comparison */ -}}
  {{- $memoryLimitUnit := regexFind "[A-Za-z]+" $memoryLimit }}
  {{- $memoryLimitValue := regexFind "[0-9]+" $memoryLimit | int64 }}
  {{- $memoryLimitMi := 0 }}
  {{- if or (eq $memoryLimitUnit "M") (eq $memoryLimitUnit "Mi") }}
    {{- $memoryLimitMi = $memoryLimitValue }}
  {{- else if or (eq $memoryLimitUnit "G") (eq $memoryLimitUnit "Gi") }}
    {{- $memoryLimitMi = mul $memoryLimitValue 1024 }}
  {{- end }}
  {{- /* Calculate minimum required memory (heap + 512Mi overhead) */ -}}
  {{- $minRequiredMi := add $heapSizeMi 512 }}
  {{- if lt $memoryLimitMi $minRequiredMi }}
    {{- fail (printf "Memory limit (%s) must be at least %dMi (heapSize %s + 512Mi overhead). Current heapSize: %s requires memory limit of at least %dMi" $memoryLimit $minRequiredMi $heapSize $heapSize $minRequiredMi) }}
  {{- end }}
{{- end }}
{{- end }}
