# ---------------------------------------------
# Overleaf with TeX Live Full
# You must have the image sharelatex/sharelatex:ext-ce built on this machine.
# Check the documentation for more details.
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
