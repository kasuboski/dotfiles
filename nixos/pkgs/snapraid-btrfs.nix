{
  symlinkJoin,
  fetchFromGitHub,
  writeScriptBin,
  makeWrapper,
  coreutils,
  gnugrep,
  gawk,
  gnused,
  snapraid,
  snapper,
}: let
  name = "snapraid-btrfs";
  deps = [coreutils gnugrep gawk gnused snapraid snapper];
  script =
    (
      writeScriptBin name
      (builtins.readFile ((fetchFromGitHub {
          owner = "automorphism88";
          repo = "snapraid-btrfs";
          rev = "8cdbf54100c2b630ee9fcea11b14f58a894b4bf3";
          sha256 = "IQgL55SMwViOnl3R8rQ9oGsanpFOy4esENKTwl8qsgo=";
        })
        + "/snapraid-btrfs"))
    )
    .overrideAttrs (old: {
      buildCommand = "${old.buildCommand}\n patchShebangs $out";
    });
in
  symlinkJoin {
    inherit name;
    paths = [script] ++ deps;
    buildInputs = [makeWrapper];
    postBuild = "wrapProgram $out/bin/${name} --set PATH $out/bin";
  }
