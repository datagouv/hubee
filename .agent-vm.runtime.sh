#!/usr/bin/env bash
# Per-project runtime — exécuté DANS la VM agent-vm à chaque démarrage,
# après ~/.agent-vm/runtime.sh user-scope.
#
# Doc agent-vm : https://github.com/sylvinus/agent-vm
#
# Idempotent : rejouer ce script ne refait rien si Ruby et gems sont déjà
# installés. Coût significatif uniquement à la création d'une nouvelle VM.

set -euo pipefail

# mise refuse les configs non explicitement approuvées (sécurité contre
# l'exécution de mise.toml malveillants). Trust idempotent au démarrage VM.
mise trust

# Ruby 4.0.5 (lu depuis .mise.toml) + autres outils déclarés
mise install

# Gems Ruby — via `mise exec` car le PATH du shell n'est pas réactivé
# entre `mise install` et la suite de ce script.
mise exec -- bundle check || mise exec -- bundle install
