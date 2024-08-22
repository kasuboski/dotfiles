{
  buildGoModule,
  fetchFromGitHub,
}: let
  name = "loft";
  version = "3.2.2";
in
  buildGoModule {
    inherit version;
    pname = name;
    src = fetchFromGitHub {
      owner = "loft-sh";
      repo = "loftctl";
      rev = "v${version}";
      hash = "sha256-RULDeUa/pkJQ/qtojlu10diE+C7szrwFqCrngZAZizM=";
    };

    vendorHash = "sha256-Mg85Q6UzL9TibgNaIJnJin+w4UR9Yp2t1bkajZ87spE=";

    ldflags = [
      "-X main.version=v${version}"
    ];

    postInstall = ''
      mv $out/bin/loftctl $out/bin/loft
    '';

    meta = {
      description = "Manage Virtual Clusters";
      homepage = "https://loft.sh/";
    };
  }
