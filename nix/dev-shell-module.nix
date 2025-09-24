{
  lib,
  inputs,
  ...
}: {
  perSystem = {
    config,
    pkgs,
    ...
  }: {
    options = {
      devShell = {
        env = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {};
          description = "Environment variables to set in the development shell";
        };

        PATH = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Additional paths to prepend to PATH";
        };

        packages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [];
          description = "Additional packages to include in the shell";
        };

        process-compose = lib.mkOption {
          type = lib.types.submodule {
            options = {
              dataDir = lib.mkOption {
                type = lib.types.str;
                default = "./data";
                description = "Base data directory for all services (relative to project root)";
              };
            };
            freeformType = lib.types.attrsOf lib.types.anything;
          };
          default = {};
          description = "Process-compose settings and configurations";
        };
      };
    };

    config = let
      # Apply global dataDir to individual services
      applyGlobalDataDir = serviceConfig:
        if serviceConfig ? services
        then
          serviceConfig
          // {
            services =
              serviceConfig.services
              |> lib.mapAttrs (
                serviceName: instances:
                  instances
                  |> lib.mapAttrs (
                    instanceName: instanceConfig:
                      {dataDir = "${config.devShell.process-compose.dataDir}/${serviceName}/${instanceName}/";} // instanceConfig
                  )
              );
          }
        else serviceConfig;

      process-compose =
        (builtins.removeAttrs config.devShell.process-compose ["dataDir"])
        |> lib.mapAttrs (name: processConfig:
          {
            imports =
              [
                inputs.services-flake.processComposeModules.default
              ]
              ++ (processConfig.imports or []);
          }
          // (builtins.removeAttrs (applyGlobalDataDir processConfig) ["imports"]));

      processComposeDevShells =
        process-compose
        |> lib.mapAttrsToList (name: _: config.process-compose.${name}.services.outputs.devShell);

      processComposePackages =
        process-compose
        |> lib.mapAttrsToList (name: _: config.process-compose.${name}.outputs.package);
    in {
      inherit process-compose;

      devShells.default = lib.mkDefault (pkgs.mkShell {
        inputsFrom = processComposeDevShells;
        buildInputs = config.devShell.packages ++ processComposePackages;
        shellHook = let
          inherit (lib) concatStringsSep mapAttrsToList;

          pathEnvVar = (
            if config.devShell.PATH == []
            then {}
            else {
              PATH = ''${concatStringsSep ":" config.devShell.PATH}:$PATH'';
            }
          );

          envVars =
            (config.devShell.env // pathEnvVar)
            |> mapAttrsToList (name: value: ''export ${name}="${toString value}"'')
            |> concatStringsSep "\n";
        in ''
          ${envVars}
        '';
      });
    };
  };
}
