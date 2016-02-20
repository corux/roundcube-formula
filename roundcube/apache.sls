{% from "roundcube/map.jinja" import roundcube with context %}

include:
  - apache

roundcube-apache:
  file.managed:
    - name: /etc/httpd/conf.d/roundcube.conf
    - source: salt://roundcube/files/roundcube-apache.conf
    - template: jinja
    - defaults:
        config: {{ roundcube }}
    - watch_in:
      - module: apache-reload
