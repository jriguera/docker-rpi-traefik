#!/bin/bash
set -eo pipefail
shopt -s nullglob

# Defined in the Dockerfile but
# if undefined, populate environment variables with sane defaults
CONFIGDIR_DYNAMIC="${CONFIGDIR_DYNAMIC:-$CONFIGDIR}"
CONFIGDIR_STATIC="${CONFIGDIR_STATIC:-/etc/traefik}"
CONFIGFILE="${CONFIGFILE:-/etc/traefik.yml}"

DOMAIN="${DOMAIN:-localhost}"
DOMAIN_ROUTE_DOCKERS="${DOMAIN_ROUTE_DOCKERS:-false}"
ADMIN_HOST="${ADMIN_HOST:-admin.$DOMAIN}"
ADMIN_AUTH_USER="${ADMIN_AUTH_USER:-admin}"
ADMIN_AUTH_PASSWORD="${ADMIN_AUTH_PASSWORD:-}"
ADMIN_CONFIGFILE="${ADMIN_CONFIGFILE:-$CONFIGDIR_DYNAMIC/api.yml}"
ADMIN_PROMETHEUS="${ADMIN_PROMETHEUS:-1}"
ADMIN_PORT="${ADMIN_PORT:-$PORT_API}"

ACME_JSON="${ACME_JSON:-$CONFIGDIR_DYNAMIC/acme/letsencrypt.json}"
ACME_EMAIL="${ACME_EMAIL:-}"

PORT_HTTP="${PORT_HTTP:-80}"
PORT_HTTPS="${PORT_HTTPS:-443}"


###

# Usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="${1}"
	local def="${2:-}"

	local fvar="${var}_FILE"
	local val="${def}"

	if [ -n "${!var:-}" ] && [ -r "${fvar}" ]
	then
		echo "* Warning: both ${var} and ${fvar} are set, env ${var} takes priority"
	fi
	if [ -n "${!var:-}" ]
	then
		val="${!var}"
	elif [ -r "${fvar}" ]
	then
		val=$(< "${fvar}")
	fi
	export "${var}"="${val}"
}


random_string() {
	(
		cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-32} | head -n 1 || true
	)
}

###


[ -r "${CONFIGDIR_STATIC}/traefik.yml" ] && CONFIGFILE="${CONFIGDIR_STATIC}/traefik.yml"
[ -r "${CONFIGDIR_STATIC}/traefik.yaml" ] && CONFIGFILE="${CONFIGDIR_STATIC}/traefik.yaml"
[ -r "${CONFIGDIR_STATIC}/traefik.toml" ] && CONFIGFILE="${CONFIGDIR_STATIC}/traefik.toml"

mkdir -p "${CONFIGDIR_STATIC}"
mkdir -p "${CONFIGDIR_DYNAMIC}"
touch "${CONFIGFILE}"

# if command starts with an option, prepend traefik
if [ "${1:0:1}" == '-' ]
then
	set -- traefik --configFile="${CONFIGFILE}" "$@"
fi

# if our command is a valid Traefik subcommand, let's invoke it through Traefik instead
# (this allows for "docker run traefik version", etc)
if traefik "$1" --help >/dev/null 2>&1
then
	set -- traefik  --configFile="${CONFIGFILE}" "$@"
else
	echo "* '$1' is not a Traefik command: assuming shell execution." 1>&2
fi

# allow the container to be started with `--user`
if [ "${1}" == "traefik" ] && [ "$(id -u)" == "0" ]
then
	chown -R traefik:traefik "${CONFIGDIR_DYNAMIC}" "${CONFIGDIR_STATIC}" "${CONFIGFILE}"
	exec su-exec traefik "${BASH_SOURCE}" "$@"
fi

# if configfile is empty, generate one based on the environment variables
if [ ! -s "${CONFIGFILE}" ]
then
	echo "* Using env variables to generate configuration ..."
	cat <<- EOF > "${CONFIGFILE}"
	global:
	  checkNewVersion: false
	  sendAnonymousUsage: false
	log:
	  format: common
	  level: INFO
	accessLog:
	  bufferingSize: 10
	api:
	  insecure: false
	  dashboard: true
	ping:
	  entryPoint: "ping"
	metrics:
	  prometheus:
	    addEntryPointsLabels: true
	    addServicesLabels: true
	    entryPoint: "admin"
	providers:
	  file:
	    directory: "${CONFIGDIR}"
	    watch: false
	EOF
	if [ -S "/var/run/docker.sock" ]
	then
		cat <<- EOF >> "${CONFIGFILE}"
		  docker:
		    endpoint: "unix:///var/run/docker.sock"
		    exposedByDefault: ${DOMAIN_ROUTE_DOCKERS}
		    defaultRule: "Host(\`{{ normalize .Name }}.${DOMAIN}\`)"
		EOF
	fi
	cat <<- EOF >> "${CONFIGFILE}"
	entryPoints:
	  ping:
	    address: "127.0.0.1:8181"
	  admin:
	    address: ":${ADMIN_PORT}"
	  http:
	    address: ":${PORT_HTTP}"
	    proxyProtocol:
	      insecure: true
	    forwardedHeaders:
	      insecure: true
	EOF
	if [ -r "${ACME_JSON}" ] && [ -n "${ACME_EMAIL}" ]
	then
		echo "* Generating TLS and Letsencrypt ACME config pointing to ${ACME_JSON} ..."
		cat <<- EOF >> "${CONFIGFILE}"
		  https:
		    address: ":${PORT_HTTPS}"
		certificatesResolvers:
		  letsencrypt:
		    acme:
		      email: "${ACME_EMAIL}"
		      storage: "${ACME_JSON}"
		      httpChallenge:
		        entryPoint: https
		EOF
	fi
fi

if [ -n "${ADMIN_CONFIGFILE}" ] && [ ! -r "${ADMIN_CONFIGFILE}" ]
then
	if [ -z "${ADMIN_AUTH_PASSWORD}" ]
	then
		ADMIN_AUTH_PASSWORD=$(random_string 8)
		echo "* Generated ${ADMIN_AUTH_USER} password in ${CONFIGDIR_DYNAMIC}/${ADMIN_AUTH_USER}.password"
		echo "${ADMIN_AUTH_PASSWORD}" > "${CONFIGDIR_DYNAMIC}/${ADMIN_AUTH_USER}.password"
	fi
	[ "${DOMAIN}" == "localhost" ] && ADMIN_HOST="localhost"
	cat <<- EOF > "${ADMIN_CONFIGFILE}"
	# API Configuration
	http:
	  middlewares:
	    auth:
	      realm: "${ADMIN_HOST}"
	      basicAuth:
	        users:
	        - "$(htpasswd -nb ${ADMIN_AUTH_USER} ${ADMIN_AUTH_PASSWORD})"
	  routers:
	    api:
	      entryPoints:
	      - admin
	      rule: "(Host(\`${ADMIN_HOST}\`) || Host(\`127.0.0.1\`)) && (PathPrefix(\`/api\`) || PathPrefix(\`/dashboard\`))"
	      service: 'api@internal'
	      middlewares:
	      - auth
	EOF
	if [ "x${ADMIN_PROMETHEUS}" == "x1" ]
	then
		cat <<- EOF >> "${ADMIN_CONFIGFILE}"
		    metrics:
		      entryPoints:
		      - admin
		      rule: "(Host(\`${ADMIN_HOST}\`) || Host(\`127.0.0.1\`)) && PathPrefix(\`/metrics\`)"
		      service: 'api@internal'
		EOF
	fi
fi

exec "$@"

