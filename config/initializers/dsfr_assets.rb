# Depuis dsfr-assets 1.15, la gem lève `Dsfr::Assets::LicenseError` au boot tant que
# les CGU du DSFR ne sont pas explicitement acceptées. On déclare ici la version des
# CGU acceptée (celle du DSFR v1.15.1) :
# https://github.com/GouvernementFR/dsfr/blob/v1.15.1/doc/legal/cgu.md
Dsfr::Assets.accepted_license_version = "1.0.1"
