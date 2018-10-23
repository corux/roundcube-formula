{% from "roundcube/map.jinja" import imapproxy with context %}

imapproxy:
  pkg.installed:
    - name: up-imapproxy

  service.running:
    - name: imapproxy
    - enable: True
    - require:
      - pkg: imapproxy
      - cmd: imapproxy-trim-whitespaces

{% for key, value in imapproxy.config.items() %}
imapproxy-config-{{ key }}:
  file.replace:
    - name: /etc/imapproxy.conf
    - pattern: '^#?[ \t]*{{ key }}\s.*$'
    - repl: {{ key }} {{ value }}
    - append_if_not_found: True
    - watch_in:
      - service: imapproxy
      - cmd: imapproxy-trim-whitespaces
{% endfor %}

imapproxy-trim-whitespaces:
  cmd.wait:
    - name: "sed 's/^[ \t]*//' --in-place /etc/imapproxy.conf"
    - watch:
      - pkg: imapproxy
