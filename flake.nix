{
  description = "Terraform module for OLM";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { flake-utils, nixpkgs, self }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; }; in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.cocogitto
            pkgs.curl
            pkgs.shellcheck
            pkgs.terraform
            pkgs.tfk8s
          ];
        };
        formatter = pkgs.nixpkgs-fmt;
      }
    );
}
