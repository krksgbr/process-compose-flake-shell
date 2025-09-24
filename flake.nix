{
  description = "Example dev-shell with process-compose-flake";
  nixConfig = {
    extra-experimental-features = "nix-command flakes pipe-operators";
  };
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/25.11-pre";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = import inputs.systems;
      imports = [
        inputs.process-compose-flake.flakeModule
        ./nix/dev-shell-module.nix
      ];
      perSystem = {pkgs, ...}: {
        # Configure our dev shell using the module system
        devShell = {
          packages = with pkgs; [
            just
            bun
          ];

          env = {
            ROOT_DIR = "$PWD";
          };

          PATH = [
            "$PWD/scripts"
            "$PWD/node_modules/.bin"
          ];

          # Process-compose configurations are now part of the devShell
          process-compose = {
            dataDir = ".dev-data";
            # run `start-services` inside the dev-shell, to start these services
            start-services = {
              services.postgres."pg1" = {
                enable = true;
              };
            };
          };
        };
      };
    };
}
