=================
roundcube-formula
=================
.. image:: https://github.com/corux/roundcube-formula/workflows/Test/badge.svg?branch=master

Installs the Roundcube webmail software.

Available states
================

.. contents::
    :local:

``roundcube``
-------------

Installs the Roundcube webmail software. Includes ``roundcube.selinux``, if SELinux is enabled.

``roundcube.apache``
--------------------

Adds a dependency to the apache formula and configures a roundcube site.

``roundcube.imapproxy``
-----------------------

Installs and configures the IMAP Proxy (http://www.imapproxy.org/).
The IMAP Proxy can be used to improve Roundcube's performance.

``roundcube.selinux``
---------------------

Configures roundcube to work with SELinux.
