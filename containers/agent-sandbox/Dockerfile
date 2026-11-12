# check=skip=InvalidDefaultArgInFrom
# FROM inputs deliberately have no defaults: AIW supplies reviewed registry digests.
# AIW operator-reviewed image only. Docker build receives immutable registry digests.
# Build context contains this Dockerfile alone; no secrets or project files.
ARG UV_BASE
ARG BASE
FROM ${UV_BASE} AS uv
FROM ${BASE}
USER root
COPY --from=uv /uv /uvx /usr/local/bin/
ENV UV_PYTHON_INSTALL_DIR=/opt/aiw/pythons
RUN UV_CACHE_DIR=/tmp/uv-build uv python install 3.12.12 && \
    ln -s "$(uv python find --python-preference only-managed 3.12.12)" /usr/local/bin/python3 && \
    mkdir -p /opt/aiw/tools /opt/aiw/bin && \
    chown -R 1000:1000 /opt/aiw/tools /opt/aiw/bin && \
    rm -rf /tmp/uv-build
ENV UV_CACHE_DIR=/home/goose/.cache/uv
ENV UV_TOOL_DIR=/home/goose/.local/share/uv/tools
ENV UV_TOOL_BIN_DIR=/home/goose/.local/bin
ENV PATH=/home/goose/.local/bin:/opt/aiw/bin:/usr/local/bin:/usr/bin:/bin
USER goose
WORKDIR /workspace
ENTRYPOINT ["goose"]
