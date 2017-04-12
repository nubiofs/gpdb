#!/bin/bash -l

set -euxo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

substitute_GP_VERSION() {
  GP_VERSION=$("$DIR/../../getversion" --short)
  INSTALLER_ZIP=${INSTALLER_ZIP//@GP_VERSION@/${GP_VERSION}}
}

function setup_rpm_buildroot_centos6() {
  mkdir -p /root/rpmbuild/{SOURCES,SPECS}
  cp ${GPDB_TARGZ} /root/rpmbuild/SOURCES/gpdb.tar.gz
}

function generate_rpm_spec() {

  cat << EOF > /root/rpmbuild/SPECS/gpdb.spec
Name: greenplum-db
Version: 5.0.0
Release: 1
Summary: foobar
Group: Development/Tools
License: GPL
URL: None
Source0: gpdb.tar.gz
Buildroot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

%define prefix /usr/local/
%define bin_gpdb %{prefix}%{name}-%{version}

%description
foobar

%prep
%setup -c -n %{name}-%{version}

%install
rm -rf \$RPM_BUILD_ROOT
mkdir -p \$RPM_BUILD_ROOT%{bin_gpdb}
cp -R * \$RPM_BUILD_ROOT%{bin_gpdb}
# Disable build root policy trying to generate %.pyo/%.pyc
exit 0

%files
%{bin_gpdb}

%clean
rm -rf \$RPM_BUILD_ROOT
EOF
}

function echo_expected_env_variables() {
  echo "$INSTALL_SCRIPT_SRC"
  echo "$GPDB_TARGZ"
  echo "$INSTALLER_ZIP"
}

function _main() {
  substitute_GP_VERSION
  echo_expected_env_variables
  setup_rpm_buildroot_centos6
  generate_rpm_spec

  # Copy gpaddon into addon to ensure the availability of all the installer scripts
  cp -R gpaddon_src gpdb_src/gpAux/addon

  local installer_bin
  installer_bin=$( echo "$INSTALLER_ZIP" | sed "s/.zip/.bin/" | xargs basename)

  GP_VERSION=$("${DIR}/../../getversion" --short)
  sed -i \
      -e "s:\(installPath=/usr/local/GP-\).*:\1$GP_VERSION:" \
      -e "s:\(installPath=/usr/local/greenplum-db-\).*:\1$GP_VERSION:" \
      "$INSTALL_SCRIPT_SRC"

  cat "$INSTALL_SCRIPT_SRC" "$GPDB_TARGZ" > "$installer_bin"
  chmod a+x "$installer_bin"
  zip "$INSTALLER_ZIP" "$installer_bin"
  openssl dgst -md5 "$INSTALLER_ZIP" > "$INSTALLER_ZIP".md5

  rpmbuild -bb /root/rpmbuild/SPECS/gpdb.spec

}

_main "$@"
