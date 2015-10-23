module level.levelio;

/* Input/output of the normal Lix level format. This format uses file.io.
 * Lix can also read levels from Lemmings 1 or Lemmini, those input functions
 * are in separate files of this package.
 */

import std.stdio;
import std.algorithm;

static import glo = basics.globals;

import basics.help; // positiveMod
import file.date;
import file.filename;
import file.io;
import file.log;
import file.search; // test if file exists
import level.level;
import level.tile;
import level.tilelib;
import lix.enums;

// private FileFormat get_file_format(in Filename);

package void loadFromFile(Level level, in Filename fn)
{
    level._status = LevelStatus.GOOD;

    final switch (get_file_format(fn)) {
    case FileFormat.NOTHING:
        level._status = LevelStatus.BAD_FILE_NOT_FOUND;
        break;
    case FileFormat.LIX:
        try
            load_from_vector(level, fillVectorFromFile(fn));
        catch (Exception e)
            level._status = LevelStatus.BAD_FILE_NOT_FOUND;
        break;
    case FileFormat.BINARY:
        // load an original .LVL file from L1/ONML/...
        // DTODOLEVELFORMAT
        // load_from_binary(level, fn);
        break;
    case FileFormat.LEMMINI:
        // DTODOLEVELFORMAT
        // load_from_lemmini(level, fn);
        break;
    }
    level.load_level_finalize();
}



package FileFormat get_file_format(in Filename fn)
{
    if (! file_exists(fn)) return FileFormat.NOTHING;
    else return FileFormat.LIX;

    // DTODO: Implement the remaining function from C++/A4 Lix that opens
    // a file in binary mode. Implement L1 loader functions.
    // Consider taking not a Filename, but an already opened (ref std.File)!
}



// ############################################################################
// ################################################ Loading the Lix file format
// ############################################################################



private void tuto(ref string[] into, in string what)
{
    // this always goes into index 0
    if (into == null) into   ~= what;
    else              into[0] = what;
}

private void hint(ref string[] into, in string what)
{
    // empty hints aren't allowed, all hints shall be in consecutive entries
    if (what == null) return;

    // hint 0 is the tutorial hint, this should be empty for most levels.
    if (into == null) into ~= "";
    into ~= what;
}



private void load_from_vector(Level level, in IoLine[] lines)
{
    with (level)
{
    foreach (line; lines) with (line) switch (type) {
    // set a string
    case '$':
        if      (text1 == glo.levelBuilt       ) built = new Date(text2);

        else if (text1 == glo.levelAuthor      ) author       = text2;
        else if (text1 == glo.levelName_german ) nameGerman  = text2;
        else if (text1 == glo.levelName_english) nameEnglish = text2;

        else if (text1 == glo.levelHintGerman ) hint(hintsGerman,  text2);
        else if (text1 == glo.levelHintEnglish) hint(hintsEnglish, text2);
        else if (text1 == glo.levelTutorialGerman ) tuto(hintsGerman,  text2);
        else if (text1 == glo.levelTutorialEnglish) tuto(hintsEnglish, text2);
        break;

    // set an integer
    case '#':
        if      (text1 == glo.levelStartX ) {
            startManual = true;
            startX      = nr1;
        }
        else if (text1 == glo.levelStartY ) {
            startManual = true;
            startY      = nr1;
        }
        else if (text1 == glo.levelSizeX       ) sizeX        = nr1;
        else if (text1 == glo.levelSizeY       ) sizeY        = nr1;
        else if (text1 == glo.levelTorusX      ) torusX       = nr1 > 0;
        else if (text1 == glo.levelTorusY      ) torusY       = nr1 > 0;
        else if (text1 == glo.levelBackgroundRed       ) bgRed        = nr1;
        else if (text1 == glo.levelBackgroundGreen     ) bgGreen      = nr1;
        else if (text1 == glo.levelBackgroundBlue      ) bgBlue       = nr1;
        else if (text1 == glo.levelSeconds      ) seconds       = nr1;
        else if (text1 == glo.levelInitial      ) initial       = nr1;
        else if (text1 == glo.levelRequired     ) required      = nr1;
        else if (text1 == glo.levelSpawnintSlow) spawnintSlow = nr1;
        else if (text1 == glo.levelSpawnintFast) spawnintFast = nr1;

        else if (text1 == glo.levelCountNeutralsOnly)
                                             countNeutralsOnly = nr1 > 0;
        else if (text1 == glo.levelTransferSkills)
                                             transferSkills     = nr1 > 0;

        // legacy support
        else if (text1 == glo.levelInitialLegacy) initial      = nr1;
        else if (text1 == glo.levelRateLegacy) {
            spawnintSlow = 4 + (99 - nr1) / 2;
        }

        // If nothing matched yet, look up the skill name.
        // We can't add skills if we've reached the globally allowed maximum.
        // If we've read in only rubbish, we don't add the skill.
        else {
            Ac ac = lix.enums.stringToAc(text1);
            if (ac != Ac.MAX)
                skills[ac] = nr1;
        }
        break;

    // new tile for the level
    case ':':
        add_object_from_ascii_line(level, text1, nr1, nr2, text2);
        break;

    default:
        break;
    }

    // LEGACY SUPPORT: Very old levels have sorted backwards the terrain.
    // Also, in general: Exclude the zero Date. Saved original .LVLs have a
    // time of 0. In early 2011, the maximal number of skills was raised.
    // Prior to that, infinity was 100, and finite skill counts had to be
    // <= 99. Afterwards, infinity was -1, and the maximum skill count was 999.
    auto zero_date = new Date("0");
    if (built != zero_date && built < new Date("2009-08-23 00:00:00")) {
        // DTODOCOMPILERUPDATE
        // pos[TileType.TERRAIN].reverse();
    }
    if (built != zero_date && built < new Date("2011-01-08 00:00:00"))
        foreach (Ac ac, ref int nr; skills.byKeyValue)
            if (nr == 100)
                nr = lix.enums.skillInfinity;
}
// end with

}
// end function load_from_vector



private void add_object_from_ascii_line(
    Level     level,
    in string text1,
    in int    nr1,
    in int    nr2,
    in string text2
) {
    const(Tile) ob = get_tile(text1);
    if (ob && ob.cb) {
        Pos newpos = Pos(ob);
        newpos.x  = nr1;
        newpos.y  = nr2;
        if (ob.type == TileType.TERRAIN)
         foreach (char c; text2) switch (c) {
            case 'f': newpos.mirr = ! newpos.mirr;         break;
            case 'r': newpos.rot  =  (newpos.rot + 1) % 4; break;
            case 'd': newpos.dark = ! newpos.dark;         break;
            case 'n': newpos.noow = ! newpos.noow;         break;
            default: break;
        }
        else if (ob.type == TileType.HATCH)
         foreach (char c; text2) switch (c) {
            case 'r': newpos.rot  = !newpos.rot; break;
            default: break;
        }
        level.pos[ob.type] ~= newpos;
    }
    // image doesn't exist
    // record a missing image in the logfile
    else {
        level._status = LevelStatus.BAD_IMAGE;
        Log.logf("Missing image `%s'", text1);
    }
}



private void load_level_finalize(Level level)
{
    with (level) {
        // set some standards, in case we've read in rubbish values
        if (sizeX   < minXl)             sizeX   = Level.minXl;
        if (sizeY   < minYl)             sizeY   = Level.minYl;
        if (sizeX   > maxXl)             sizeX   = Level.maxXl;
        if (sizeY   > maxYl)             sizeY   = Level.maxYl;
        if (initial  < 1)                  initial  = 1;
        if (initial  > 999)                initial  = 999;
        if (required > initial)            required = initial;
        if (spawnintFast < spawnintMin)  spawnintFast = Level.spawnintMin;
        if (spawnintSlow > spawnintMax)  spawnintSlow = Level.spawnintMax;
        if (spawnintFast > spawnintSlow) spawnintFast = spawnintSlow;

        if (bgRed   < 0) bgRed   = 0; if (bgRed   > 255) bgRed   = 255;
        if (bgGreen < 0) bgGreen = 0; if (bgGreen > 255) bgGreen = 255;
        if (bgBlue  < 0) bgBlue  = 0; if (bgBlue  > 255) bgBlue  = 255;

        if (torusX) startX = positiveMod(startX, sizeX);
        if (torusY) startY = positiveMod(startY, sizeY);

        // Set level error. The error for file not found, or the error for
        // missing tile images, have been set already.
        if (_status == LevelStatus.GOOD) {
            int count = 0;
            foreach (poslist; pos)
                count += poslist.length;
            foreach (Ac ac, const int nr; skills)
                count += nr;
            if (count == 0)
                _status = LevelStatus.BAD_EMPTY;
            else if (pos[TileType.HATCH] == null)
                _status = LevelStatus.BAD_HATCH;
            else if (pos[TileType.GOAL ] == null)
                _status = LevelStatus.BAD_GOAL;
        }
    }
    // end with
}



// ############################################################################
// ###################################### Saving a level in the Lix file format
// ############################################################################



package void implSaveToFile(const(Level) level, in Filename fn)
{
    try {
        std.stdio.File file = File(fn.rootful, "w");
        saveToFile(level, file);
        file.close();
    }
    catch (Exception e) {
        Log.log(e.msg);
    }
}



public void saveToFile(const(Level) l, std.stdio.File file)
{
    assert (l);

    file.writeln(IoLine.Dollar(glo.levelBuilt,        l.built       ));
    file.writeln(IoLine.Dollar(glo.levelAuthor,       l.author      ));
    file.writeln(IoLine.Dollar(glo.levelName_german,  l.nameGerman ));
    file.writeln(IoLine.Dollar(glo.levelName_english, l.nameEnglish));
    file.writeln();

    // write hint
    void wrhi(in string[] hints, in string str_tuto, in string str_hint)
    {
        // index 0 is the tutorial hint
        foreach (int i, string str; hints)
        if (i == 0) {
            if (str != null) file.writeln(IoLine.Dollar(str_tuto, str));
        }
        else file.writeln(IoLine.Dollar(str_hint, str));
    }


    wrhi(l.hintsGerman,  glo.levelTutorialGerman,  glo.levelHintGerman );
    wrhi(l.hintsEnglish, glo.levelTutorialEnglish, glo.levelHintEnglish);
    if (l.hintsGerman != null || l.hintsEnglish != null) {
        file.writeln();
    }

    file.writeln(IoLine.Hash(glo.levelSizeX,  l.sizeX ));
    file.writeln(IoLine.Hash(glo.levelSizeY,  l.sizeY ));
    if (l.torusX || l.torusY) {
        file.writeln(IoLine.Hash(glo.levelTorusX, l.torusX));
        file.writeln(IoLine.Hash(glo.levelTorusY, l.torusY));
    }
    if (l.startManual) {
        file.writeln(IoLine.Hash(glo.levelStartX, l.startX));
        file.writeln(IoLine.Hash(glo.levelStartY, l.startY));
    }
    if (l.bgRed != 0 || l.bgGreen != 0 || l.bgBlue != 0) {
        file.writeln(IoLine.Hash(glo.levelBackgroundRed,   l.bgRed  ));
        file.writeln(IoLine.Hash(glo.levelBackgroundGreen, l.bgGreen));
        file.writeln(IoLine.Hash(glo.levelBackgroundBlue,  l.bgBlue ));
    }
    file.writeln();

    file.writeln(IoLine.Hash(glo.levelSeconds,       l.seconds ));
    file.writeln(IoLine.Hash(glo.levelInitial,       l.initial ));
    file.writeln(IoLine.Hash(glo.levelRequired,      l.required));
    file.writeln(IoLine.Hash(glo.levelSpawnintSlow, l.spawnintSlow));
    file.writeln(IoLine.Hash(glo.levelSpawnintFast, l.spawnintFast));
//  file.writeln(IoLine.Hash(glo.levelCountNeutralsOnly, l.countNeutralsOnly));
//  file.writeln(IoLine.Hash(glo.levelTransferSkills,     l.transferSkills));

    bool at_least_one_skill_written = false;
    foreach (Ac sk, const int nr; l.skills.byKeyValue) {
        if (nr == 0)
            continue;
        if (! at_least_one_skill_written) {
            at_least_one_skill_written = true;
            file.writeln();
        }
        file.writeln(IoLine.Hash(acToString(sk), nr));
    }

    // this local function outputs all tiles of a given type
    void save_one_tile_vector(in Pos[] vec)
    {
        if (vec != null) {
            file.writeln();
        }
        foreach (tile; vec) {
            if (tile.ob is null) continue;
            string str = get_filename(tile.ob);
            if (str == null) continue;

            string modifiers;
            if (tile.mirr) modifiers ~= 'f';
            foreach (r; 0 .. tile.rot) modifiers ~= 'r';
            if (tile.dark) modifiers ~= 'd';
            if (tile.noow) modifiers ~= 'n';
            file.writeln(IoLine.Colon(str, tile.x, tile.y, modifiers));
        }
    }

    // print all special objects, then print all terrain.
    foreach (ref const(Pos[]) vec; l.pos) {
        if (vec is l.pos[TileType.TERRAIN]) continue;
        save_one_tile_vector(vec);
    }
    save_one_tile_vector(l.pos[TileType.TERRAIN]);

}
