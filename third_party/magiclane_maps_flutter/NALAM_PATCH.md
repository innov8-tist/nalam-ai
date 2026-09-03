# Nalam Android compatibility patch

This directory is based on `magiclane_maps_flutter` 3.1.11.

The host app uses AGP 9.1 with Flutter's temporary legacy Kotlin/DSL flags for
compatibility with its existing plugins. The upstream 3.1.11 Gradle script
assumes built-in Kotlin and also references generated Kotlin-script labels that
do not resolve with Gradle 9.3.1 in this configuration.

The local wrapper therefore:

- uses the public AGP `LibraryExtension` API;
- applies `org.jetbrains.kotlin.android` while the host opts out of built-in
  Kotlin;
- relies on the default `src/main/kotlin` source directory;
- captures task inputs in named project variables instead of generated script
  labels.

No Dart API or native Magic Lane SDK code is changed. Remove this fork and
return to the hosted dependency after an upstream release resolves the Gradle
script incompatibility.
