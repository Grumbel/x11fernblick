{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        packages = rec {
          default = x11fernblick;

          x11fernblick = pkgs.stdenv.mkDerivation rec {
            pname = "x11fernblick";
            version = "0.0.0";

            src = ./.;

            installPhase = ''
              substituteInPlace x11fernblick.sh \
                --replace 'VNCVIEWER=vncviewer' \
                          'VNCVIEWER=${pkgs.tigervnc}/bin/vncviewer' \
                --replace 'SS=ss' \
                          'SS=${pkgs.iproute2}/bin/ss'
              mkdir -p $out/bin
              cp -v x11fernblick.sh $out/bin/x11fernblick
            '';
          };
        };
      }
    );
}
