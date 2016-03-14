{% from "roundcube/map.jinja" import imapproxy with context %}

imapproxy:
  pkg.installed:
    - name: up-imapproxy

  service.running:
    - name: imapproxy
    - enable: True
    - require:
      - pkg: imapproxy

{% for key, value in imapproxy.config.items() %}
imapproxy-config-{{ key }}:
  file.replace:
    - name: /etc/imapproxy.conf
    - pattern: '^#?[ \t]*{{ key }}\s.*$'
    - repl: {{ key }} {{ value }}
    - append_if_not_found: True
    - watch_in:
      - service: imapproxy
{% endfor %}
