{% from 'roundcube/map.jinja' import roundcube with context %}
{% from 'selinux/map.jinja' import selinux with context %}

include:
  - php.ng
  - php.ng.intl
  - php.ng.mbstring
  - php.ng.xml
  - php.ng.pear
  - php.ng.{{ 'mysql' if roundcube.get('config', {}).get('db_dsnw').startswith('mysql') else 'pgsql' }}
{% if selinux.enabled %}
  - .selinux
{% endif %}

roundcube-extractdir:
  file.directory:
    - name: {{ roundcube.extract }}
    - mode: 755
    - makedirs: True

roundcube-download:
  cmd.run:
    - name: "curl -L --silent '{{ roundcube.url }}' > '{{ roundcube.source }}'"
    - unless: "test -f '{{ roundcube.source }}'"
    - prereq:
      - archive: roundcube-install

roundcube-install:
  archive.extracted:
    - name: {{ roundcube.extract }}
    - source: {{ roundcube.source }}
    - archive_format: tar
    - tar_options: z
    - if_missing: {{ roundcube.current }}
    - user: root
    - group: root
    - require:
      - file: roundcube-extractdir

  file.symlink:
    - name: {{ roundcube.install }}
    - target: {{ roundcube.current }}
    - require:
      - archive: roundcube-install

{% for dir in [ 'temp', 'logs' ] %}
roundcube-chmod-{{ dir }}:
  file.directory:
    - name: {{ roundcube.install }}/{{ dir }}
    - user: apache
    - group: apache
    - mode: 755
    - recurse:
      - user
      - group
    - require:
      - file: roundcube-install
{% endfor %}

roundcube-update:
  cmd.run:
    - name: './bin/update.sh --accept --version=$(grep RCMAIL_VERSION "{{ roundcube.install }}/program/include/iniset.php"|grep -E -o "[0-9\.]+[a-z\-]*")'
    - cwd: {{ roundcube.current }}
    - onlyif: test -e {{ roundcube.install }} && test "$(readlink -f '{{ roundcube.install }}')" != "{{ roundcube.current }}"
    - require:
      - archive: roundcube-install
    - require_in:
      - file: roundcube-install

{%- macro php_serialize(value) %}
{%- if value is string or value is number -%}
  {{ value|json }}
{%- elif value is iterable -%}
array(
  {%- for inner in value -%}
  {{ php_serialize(inner) }},
  {%- endfor -%}
)
{%- elif value is none -%}
  null
{%- else -%}
  {{ value|json }}
{%- endif %}
{%- endmacro %}

roundcube-config:
  file.managed:
    - name: {{ roundcube.install }}/config/config.inc.php
    - mode: 640
    - group: apache
    - require:
      - file: roundcube-install
    - contents: |
        <?php
        $config = array();
{%- for key, val in roundcube.get('config', {}).items() %}
        $config['{{ key }}'] = {{ php_serialize(val) }};
{%- endfor %}
