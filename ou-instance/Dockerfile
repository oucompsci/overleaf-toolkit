# ---------------------------------------------
# Overleaf with TeX Live Full
# You must have the image sharelatex/sharelatex:ext-ce built on this machine.
# Check the documentation for more details.
# That is, this dockerfile will extend the base image sharelatex/sharelatex:ext-ce image.
# Use `docker build -t sharelatex/sharelatex:ext-ce-full .` in this directory to build this image.
# Afterwards, check overleaf-toolkit/config/docker-compose.override.yml to see how to override to ensure this new image is used.
# ---------------------------------------------

ARG OVERLEAF_BASE_TAG=sharelatex/sharelatex:ext-ce
FROM $OVERLEAF_BASE_TAG

# Install TeX Live Full
# This installs all available LaTeX packages (~several GB)
# Based on instructions from docs/adding-packages.md
RUN tlmgr install scheme-full && \
    tlmgr path add

EXPOSE 80
ENTRYPOINT ["/sbin/my_init"]
