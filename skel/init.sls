---
{%- from "skel/map.jinja" import skel with context %}

{#- custom_source (if set) fully replaces the built-in default body;
    otherwise use_default decides whether the built-in body is used at
    all. Either way the result lands at /etc/skel/.bashrc_default and is
    conditionally sourced by the /etc/skel/.bashrc loader below. #}
{%- set body_source = skel.custom_source if skel.custom_source
                       else ('salt://skel/files/bashrc' if skel.use_default else '') %}

{%- if skel.enabled %}

{%- if body_source %}
/etc/skel/.bashrc_default:
  file.managed:
    - user: root
    - group: root
    - mode: '{{ skel.mode }}'
    - source: {{ body_source }}
    - template: jinja
    - context:
        editor: {{ skel.editor | yaml }}
        ssh_agent_autostart: {{ skel.ssh_agent_autostart }}
{%- else %}
/etc/skel/.bashrc_default:
  file.absent: []
{%- endif %}

/etc/skel/.bashrc:
  file.managed:
    - user: root
    - group: root
    - mode: '{{ skel.mode }}'
    - source: salt://skel/files/bashrc_loader
    - template: jinja
    - context:
        body: {{ (body_source != '') }}
        includes: {{ skel.includes | json }}

{%- else %}

/etc/skel/.bashrc:
  file.absent: []
/etc/skel/.bashrc_default:
  file.absent: []

{%- endif %}
