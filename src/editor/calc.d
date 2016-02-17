module editor.calc;

import editor.editor;
import editor.tiles;
import hardware.mousecur;

package:

void implEditorCalc(Editor editor) { with (editor)
{
    _map.calcScrolling();
    if (_map.scrollingNow)
        mouseCursor.xf = 3;
    editor.hoverTiles();
}}
