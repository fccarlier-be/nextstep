// Décode les tables de superposition de la carte du monde en deux fichiers TSV,
// convertis ensuite en données de l'addon par Tools/worldmap/generate.lua.
//
//   Export <dossier des .db2> <dossier des .dbd> <build> <dossier de sortie>
//
// overlays.tsv : ID, UiMapArtID, largeur, hauteur, décalage X, décalage Y,
//                PlayerConditionID, Flags, AreaID (séparés par des virgules)
// tiles.tsv    : ID, WorldMapOverlayID, rangée, colonne, couche, FileDataID
using System.Globalization;
using DBCD;
using DBCD.Providers;

if (args.Length != 4)
{
    Console.Error.WriteLine("usage: Export <db2 dir> <dbd dir> <build> <output dir>");
    return 2;
}
var (db2Dir, dbdDir, build, outDir) = (args[0], args[1], args[2], args[3]);
var dbcd = new DBCD.DBCD(new FilesystemDBCProvider(db2Dir), new FilesystemDBDProvider(dbdDir));

static string Int(object value) => Convert.ToInt64(value, CultureInfo.InvariantCulture).ToString(CultureInfo.InvariantCulture);

Directory.CreateDirectory(outDir);

var overlays = dbcd.Load("WorldMapOverlay", build);
using (var w = new StreamWriter(Path.Combine(outDir, "overlays.tsv")) { NewLine = "\n" })
{
    foreach (var row in overlays.Values.OrderBy(r => Convert.ToInt64(r["ID"])))
    {
        var areas = string.Join(",", ((Array)row["AreaID"]).Cast<object>().Select(Int));
        w.WriteLine(string.Join("\t", Int(row["ID"]), Int(row["UiMapArtID"]), Int(row["TextureWidth"]),
            Int(row["TextureHeight"]), Int(row["OffsetX"]), Int(row["OffsetY"]), Int(row["PlayerConditionID"]),
            Int(row["Flags"]), areas));
    }
}

var tiles = dbcd.Load("WorldMapOverlayTile", build);
using (var w = new StreamWriter(Path.Combine(outDir, "tiles.tsv")) { NewLine = "\n" })
{
    foreach (var row in tiles.Values.OrderBy(r => Convert.ToInt64(r["ID"])))
    {
        w.WriteLine(string.Join("\t", Int(row["ID"]), Int(row["WorldMapOverlayID"]), Int(row["RowIndex"]),
            Int(row["ColIndex"]), Int(row["LayerIndex"]), Int(row["FileDataID"])));
    }
}

Console.WriteLine($"{overlays.Count} superpositions, {tiles.Count} tuiles -> {outDir}");
return 0;
