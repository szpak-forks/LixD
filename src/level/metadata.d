module level.metadata;

import basics.globals;
import file.date;
import file.filename;
import file.io;
import level.level;
import level.levelio;

class LevelMetaData {

    FileFormat format;
    Date       built;
    int        initial;
    int        required;
    string     nameGerman;
    string     nameEnglish;



this(in Filename fn)
{
    format = level.levelio.get_file_format(fn);

    if      (format == FileFormat.LIX)     read_metadata_lix    (fn);
    else if (format == FileFormat.BINARY)  read_metadata_binary (fn);
    else if (format == FileFormat.LEMMINI) read_metadata_lemmini(fn);
}



@property string
name() const
{
    // DTODO, see comment in like-named function in level.level
    return nameEnglish == null ? nameGerman : nameEnglish;
}



@property bool
file_exists() const
{
    return format != FileFormat.NOTHING;
}



private void
read_metadata_lix(in Filename fn)
{
    IoLine[] lines = fillVectorFromFileNothrow(fn);
    foreach (i; lines) {
        if (i.text1 == levelBuilt)        built        = new Date(i.text2);
        if (i.text1 == levelName_german)  nameGerman  = i.text2;
        if (i.text1 == levelName_english) nameEnglish = i.text2;
        if (i.text1 == levelInitial)      initial      = i.nr1;
        if (i.text1 == levelRequired)     required     = i.nr1;
    }
}



// these functions are defined in levelBi.cpp
// std::string read_levelName_bytes (std::ifstream&);
// int         read_two_bytes_levelbi(std::ifstream&);
private void read_metadata_binary(in Filename fn)
{
    import file.log;
    Log.log("DTODO: reading binary metadata not impl");
    /*
    std::ifstream file(fn.rootful.c_str(), std::ios::binary);

    // see levelBi.cpp for documentation of the L1 format
    file.seekg(0x2);
    initial  = read_two_bytes_levelbi(file);
    required = read_two_bytes_levelbi(file);
    nameEnglish = read_levelName_bytes(file);
    file.close();
    */
}



private void
read_metadata_lemmini(in Filename fn)
{
    import file.log;
    Log.log("DTODO: reading Lemmini metadata not impl");
    /*
    std::ifstream file(fn.rootful.c_str());
    if (! file.good()) return;

    // File exists
    std::string s;
    while (file >> s) {
        if (s == "name") {
            file >> s; // parse the "=";
            s.clear();
            char c;
            while (file.get(c)) {
                if (c == ' ' && s.empty()); // discard spaces before name
                else if (c == '\n' || c == '\r') break; // done reading name
                else s += c;
            }
            nameEnglish = s;
        }
        else if (s == "numLemmings") {
            file >> s; // parse the "="
            file >> initial;
        }
        else if (s == "numToRescue") {
            file >> s; // parse the "="
            file >> required;
        }
    }
    file.close();
    */
}
// end read_metadata_lemmini

}
// end class LevelMetaData
