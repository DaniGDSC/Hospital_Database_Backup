# Hospital Database Backup — SQL Server Environment
# Base: SQL Server 2022 on Ubuntu with AWS CLI + monitoring tools
# Build: docker build -t hospital-sqlserver .
# HIPAA: No secrets in image — all via environment variables at runtime

FROM mcr.microsoft.com/mssql/server:2022-latest

LABEL maintainer="hospital-dba@hospital.com"
LABEL project="HospitalBackupDemo"
LABEL hipaa.compliant="true"
LABEL description="SQL Server 2022 with AWS CLI, OpenSSL, and monitoring tools"

# Pin versions from config/versions.conf
ARG AWSCLI_VERSION=2.15.0

USER root

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        unzip \
        openssl \
        jq \
        cron \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI (pinned version)
RUN curl -fsSL \
        "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip" \
        -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/aws /tmp/awscliv2.zip

# Create backup and TLS directories
RUN mkdir -p /var/opt/mssql/backup/{full,differential,log,certificates,audit-export,metrics,logs} \
    && mkdir -p /var/opt/mssql/tls \
    && chown -R mssql:mssql /var/opt/mssql/backup /var/opt/mssql/tls

# Copy project scripts (no secrets — those come via .env at runtime)
COPY --chown=mssql:mssql scripts/ /app/scripts/
COPY --chown=mssql:mssql phases/ /app/phases/
COPY --chown=mssql:mssql config/versions.conf /app/config/versions.conf

WORKDIR /app

# Switch back to mssql user
USER mssql

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=5 --start-period=30s \
    CMD /opt/mssql-tools18/bin/sqlcmd \
        -S localhost -U sa -P "${MSSQL_SA_PASSWORD:-$SA_PASSWORD}" \
        -C -Q "SELECT 1" -b || exit 1

EXPOSE 14333
