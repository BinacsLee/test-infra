#!/usr/bin/env bash
# Copyright 2021 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# generates sig-k8s-infra app deployment job configs

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")

readonly OUTPUT="${SCRIPT_DIR}/sig-k8s-infra-apps.yaml"
# list of subdirs in kubernetes/k8s.io/apps
readonly APPS=(
    gcsweb
    k8s-io
    kubernetes-external-secrets
    perfdash
    prow
    publishing-bot
    sippy
    slack-infra
    triageparty-release
)

cat >"${OUTPUT}" <<EOF
# DO NOT EDIT. Automatically generated by $0

postsubmits:
  kubernetes/k8s.io:
EOF

for app in "${APPS[@]}"; do
    cat >>"${OUTPUT}" <<EOF
    - name: post-k8sio-deploy-app-${app}
      cluster: k8s-infra-prow-build-trusted
      decorate: true
      max_concurrency: 1
      # intended for ignoring changes to README.md or OWNERS
      run_if_changed: '^apps\/${app}\/(.*.yaml|deploy.sh)$'
      branches:
      - ^main$
      reporter_config:
        slack:
          channel: "k8s-infra-alerts"
          job_states_to_report:
          - success
          - failure
          - aborted
          - error
          report_template: 'Deploying ${app}: {{.Status.State}}. Commit: <{{.Spec.Refs.BaseLink}}|{{printf "%.7s" .Spec.Refs.BaseSHA}}> | <{{.Status.URL}}|Spyglass> | <https://testgrid.k8s.io/sig-k8s-infra-apps#deploy-${app}|Testgrid> | <https://prow.k8s.io/?job={{.Spec.Job}}|Deck>'
      annotations:
        testgrid-create-test-group: 'true'
        testgrid-dashboards: sig-k8s-infra-apps
        testgrid-tab-name: deploy-${app}
        testgrid-description: 'runs https://git.k8s.io/k8s.io/apps/${app}/deploy.sh if files change in kubernetes/k8s.io/apps/${app}'
        testgrid-alert-email: k8s-infra-rbac-${app}@kubernetes.io, k8s-infra-alerts@kubernetes.io
        testgrid-num-failures-to-alert: '1'
      rerun_auth_config:
        github_team_slugs:
        # proxy for sig-k8s-infra-oncall
        - org: kubernetes
          slug: sig-k8s-infra-leads
        # proxy for test-infra-oncall
        - org: kubernetes
          slug: test-infra-admins
        # TODO: sig-specific team in charge of this app
        # - org: kubernetes
        #   slug: sig-foo-bar
      spec:
        serviceAccountName: prow-deployer
        containers:
        - image: gcr.io/k8s-staging-infra-tools/k8s-infra:latest
          command:
          - ./apps/${app}/deploy.sh
EOF
done
