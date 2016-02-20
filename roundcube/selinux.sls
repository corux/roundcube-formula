{% from "roundcube/map.jinja" import roundcube with context %}

{% for dir in [ 'temp', 'logs' ] %}
roundcube-selinux-{{ dir }}:
  cmd.run:
    - name: "semanage fcontext -a -t httpd_sys_rw_content_t '{{ roundcube.install }}/{{ dir }}(/.*)?'"
    - unless: "semanage fcontext --list | grep '{{ roundcube.install }}/{{ dir }}(/.*)?' | grep httpd_sys_rw_content_t"
    - require:
      - file: roundcube-install
    - watch_in:
      - module: roundcube-selinux-restorecon
{% endfor %}

roundcube-selinux-restorecon:
  module.wait:
    - name: file.restorecon
    - path: {{ roundcube.directory }}
    - recursive: True
    - watch:
      - file: roundcube-install
