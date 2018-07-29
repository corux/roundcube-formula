{% from 'roundcube/map.jinja' import roundcube with context %}
{% from 'selinux/map.jinja' import selinux with context %}

include:
  - epel
  - php.ng
  - php.ng.gd
  - php.ng.intl
  - php.ng.mbstring
  - php.ng.xml
  - php.ng.pear
  - php.ng.{{ 'mysql' if roundcube.get('config', {}).get('db_dsnw').startswith('mysql') else 'pgsql' }}
{% if selinux.enabled %}
  - .selinux
{% endif %}

{% if roundcube.get('pkgs') %}
roundcube-deps:
  pkg.installed:
    - pkgs: {{ roundcube.pkgs }}
{% endif %}

roundcube-deps-git:
  pkg.installed:
    - name: git

roundcube-extractdir:
  file.directory:
    - name: {{ roundcube.extract }}
    - mode: 755
    - makedirs: True

roundcube-download:
  cmd.run:
    - name: "curl -L --silent '{{ roundcube.url }}' > '{{ roundcube.source }}'"
    - unless: "test -f '{{ roundcube.source }}'"

roundcube-install:
  archive.extracted:
    - name: {{ roundcube.extract }}
    - source: {{ roundcube.source }}
    - if_missing: {{ roundcube.current }}
    - require:
      - cmd: roundcube-download
      - file: roundcube-extractdir

  file.symlink:
    - name: {{ roundcube.install }}
    - target: {{ roundcube.current }}
    - require:
      - archive: roundcube-install

roundcube-composer-download:
  cmd.run:
    - name: curl -s https://getcomposer.org/installer | php
    - unless: test -f {{ roundcube.current }}/composer.phar
    - cwd: {{ roundcube.current }}
    - require:
      - archive: roundcube-install

roundcube-composer-json:
  pkg.installed:
    - name: jq

  file.managed:
    - name: {{ roundcube.current }}/composer.json-salt
    - contents: |
        {{ roundcube.get('composer', {})|json }}
    - require:
      - archive: roundcube-install

  cmd.run:
    - name: "jq -s '.[0] * .[1]' composer.json-dist composer.json-salt > composer.json"
    - cwd: {{ roundcube.current }}
    - require:
      - pkg: roundcube-composer-json
    - onchanges:
      - file: roundcube-composer-json

roundcube-composer-run:
  cmd.run:
    - name: php composer.phar update --no-dev --no-interaction
    - cwd: {{ roundcube.current }}
    - require:
      - pkg: roundcube-deps-git
    - onchanges:
      - cmd: roundcube-composer-json

{% for skin in roundcube.get('skins', []) %}
roundcube-skin-{{ skin.name }}:
  git.latest:
    - name: {{ skin.url }}
    - rev: {{ skin.version }}
    - target: {{ roundcube.current }}/skins/{{ skin.name }}
    - require:
      - pkg: roundcube-deps-git
{% endfor %}

{% for dir in [ 'temp', 'logs', 'plugins/enigma/home' ] %}
roundcube-chmod-{{ dir }}:
  file.directory:
    - name: {{ roundcube.install }}/{{ dir }}
    - user: apache
    - group: apache
    - mode: 750
    - recurse:
      - user
      - group
    - require:
      - file: roundcube-install
{% endfor %}

{%- macro get_version(dir) -%}
grep RCMAIL_VERSION {{ dir }}/program/include/iniset.php|grep -E -o [0-9\.]+[a-z\-]*
{%- endmacro %}
{% set oldversion = roundcube.directory + '/oldversion' %}

roundcube-remember-current-version:
  cmd.run:
    - name: {{ get_version(roundcube.install) }} > {{ oldversion }}
    - onlyif: test -e {{ roundcube.install }} && test "$(cat {{ oldversion }})" != "$({{ get_version(roundcube.install) }})"
    - cwd: {{ roundcube.current }}
    - require_in:
      - file: roundcube-install

roundcube-update:
  cmd.run:
    - name: ./bin/update.sh --accept --version=$(cat {{ oldversion }})
    - onlyif: test -f {{ oldversion }} && test "$(cat {{ oldversion }})" != "$({{ get_version(roundcube.install) }})"
    - cwd: {{ roundcube.current }}
    - require:
      - file: roundcube-config
      - cmd: roundcube-composer-run

{%- macro php_serialize(value) %}
{%- if value is string or value is number -%}
  {{ value|json }}
{%- elif value is mapping -%}
array(
  {%- for key, inner in value.items() -%}
  {{ php_serialize(key) }} => {{ php_serialize(inner) }},
  {%- endfor -%}
)
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

{% for file, contents in roundcube.get('custom_config', {}).items() %}
roundcube-custom-config-{{ file }}:
  file.managed:
    - name: {{ roundcube.current }}/{{ file }}
    - require:
      - cmd: roundcube-update
    - contents: |
        {{ contents|indent(8) }}
{% endfor %}

roundcube-cronjob:
  pkg.installed:
    - name: cronie

  file.managed:
    - name: /etc/cron.d/roundcube
    - mode: 600
    - contents: |
        # clean db
        30 3 * * *     root   {{ roundcube.install }}/bin/cleandb.sh
    - require:
      - pkg: roundcube-cronjob
      - file: roundcube-install
