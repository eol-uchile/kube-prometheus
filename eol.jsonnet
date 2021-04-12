local filter = {
  kubernetesControlPlane+: {
    mixin+:: {
      prometheusAlerts+:: {
        groups: std.map(
          function(group)
            if group.name == 'kubernetes-system-scheduler' then
              group {
                rules: std.filter(function(rule)
                  rule.alert != "KubeSchedulerDown",
                  group.rules
                )
              }
            else if group.name == 'kubernetes-system-controller-manager' then
              group {
                rules: std.filter(function(rule)
                  rule.alert != "KubeControllerManagerDown",
                  group.rules
                )
              }
            else if group.name == 'kubernetes-resources' then
              group {
                rules: std.filter(function(rule)
                  rule.alert != "KubeMemoryOvercommit" && rule.alert != "CPUThrottlingHigh",
                  group.rules
                )
              }
            else
              group,
          super.groups
        ),

      },
    },
  },
};

local kp =
  (import 'kube-prometheus/main.libsonnet') +
  filter +
  // Uncomment the following imports to enable its patches
  // (import 'kube-prometheus/addons/anti-affinity.libsonnet') +
  // (import 'kube-prometheus/addons/managed-cluster.libsonnet') +
  // (import 'kube-prometheus/addons/node-ports.libsonnet') +
  // (import 'kube-prometheus/addons/static-etcd.libsonnet') +
  // (import 'kube-prometheus/addons/custom-metrics.libsonnet') +
  // (import 'kube-prometheus/addons/external-metrics.libsonnet') +
  {
    values+:: {
      kubePrometheus+: {
        platform: 'kubeadm',
      },
      common+: {
        namespace: 'monitoring',
      },
      grafana+:: {
        config: {  // http://docs.grafana.org/installation/configuration/
          sections: {
            // Do not require grafana users to login/authenticate
            'auth.anonymous': { enabled: true },
          },
        },
        dashboards+:: {  // use this method to import your dashboards to Grafana
          'eol-general.json': (import 'eol/general.json'),
        },
      },
    },
    alertmanager+:: {
      alertmanager+: {
        spec+: {
          replicas: 1,
        },
      }
    },
  };

//{ 'setup/0namespace-namespace': kp.kubePrometheus.namespace } +
{
  ['setup/prometheus-operator-' + name]: kp.prometheusOperator[name]
  for name in std.filter((function(name) name != 'serviceMonitor' && name != 'prometheusRule'), std.objectFields(kp.prometheusOperator))
} +
// serviceMonitor and prometheusRule are separated so that they can be created after the CRDs are ready
{ 'prometheus-operator-serviceMonitor': kp.prometheusOperator.serviceMonitor } +
{ 'prometheus-operator-prometheusRule': kp.prometheusOperator.prometheusRule } +
{ 'kube-prometheus-prometheusRule': kp.kubePrometheus.prometheusRule } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['blackbox-exporter-' + name]: kp.blackboxExporter[name] for name in std.objectFields(kp.blackboxExporter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['kubernetes-' + name]: kp.kubernetesControlPlane[name] for name in std.objectFields(kp.kubernetesControlPlane) }
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) }
