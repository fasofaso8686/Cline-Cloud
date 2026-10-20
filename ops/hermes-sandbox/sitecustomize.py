"""Sandbox TLS compatibility shim.

Python 3.13+ enables ``ssl.VERIFY_X509_STRICT`` by default, which rejects any
certificate chain whose CA omits the ``keyUsage`` extension. The egress proxy
in this container re-signs every TLS connection with a local CA
(CN=cline-mitm-ca) that carries only ``basicConstraints=CA:TRUE``, so every
stdlib HTTPS call fails with "CA cert does not include key usage extension".

Dropping that one flag keeps full chain and hostname verification; it only
skips the RFC 5280 profile strictness. Delete this file to revert.
"""

import ssl

_create_default_context = ssl.create_default_context
_create_default_https_context = ssl._create_default_https_context


def create_default_context(*args, **kwargs):
    context = _create_default_context(*args, **kwargs)
    context.verify_flags &= ~ssl.VERIFY_X509_STRICT
    return context


# urllib (and anything else going through the https handler) uses this
# module-level alias, which was bound before this shim ran.
def _create_default_https_context_shim(*args, **kwargs):
    return create_default_context(*args, **kwargs)


create_default_context.__wrapped__ = _create_default_context
ssl.create_default_context = create_default_context
ssl._create_default_https_context = _create_default_https_context_shim
