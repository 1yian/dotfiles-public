{ pkgs }:

let
  # These three releases are outside nixpkgs. Hashes are from the publishers'
  # release manifest/checksums, not an installer that follows "latest".
  archiveTool =
    name: version: hash:
    pkgs.stdenvNoCC.mkDerivation {
      pname = name;
      inherit version;
      src = pkgs.fetchurl {
        url = "https://github.com/kunchenguid/${name}/releases/download/v${version}/${name}-v${version}-linux-amd64.tar.gz";
        sha256 = hash;
      };
      nativeBuildInputs = [ pkgs.autoPatchelfHook ];
      buildInputs = [ pkgs.stdenv.cc.cc.lib ];
      sourceRoot = ".";
      installPhase = ''
        runHook preInstall
        install -Dm755 ${name} "$out/bin/${name}"
        runHook postInstall
      '';
    };
in
{
  herdr = pkgs.stdenvNoCC.mkDerivation {
    pname = "herdr";
    version = "0.9.5";
    src = pkgs.fetchurl {
      url = "https://github.com/herdrdev/herdr/releases/download/v0.9.5/herdr-linux-x86_64";
      sha256 = "14d9e8bc8b4a9e0118d77c32266f76d461f09b40342eb23752960bd89f59929d";
    };
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
    installPhase = ''
      install -Dm755 "$src" "$out/bin/herdr"
    '';
  };
  treehouse =
    archiveTool "treehouse" "3.1.4"
      "a169277ffdc5f48b51a4b53ce6c2e46fe3c222a5017c67f72bf9260a9b382ae2";
  no-mistakes =
    archiveTool "no-mistakes" "1.84.0"
      "b0fb8a9df412c5fa1fb92a3584ffa1d4d5b4d6e0d1738efa2f8b88320f8bf1c2";
}
