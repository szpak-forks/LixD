module gui.element;

import std.algorithm;

import basics.alleg5;
import graphic.color;
import gui;
import hardware.mouse; // isMouseHere

abstract class Element {

// this(geom);

    // these functions return the position/length in geoms. See geometry.d
    // for the difference between measuring in geoms and in screen pixels.
    @property float xg()  const { return _geom.xg;  }
    @property float yg()  const { return _geom.yg;  }
    @property float xlg() const { return _geom.xlg; }
    @property float ylg() const { return _geom.ylg; }

    @property float xs()  const { return _geom.xs;  }
    @property float ys()  const { return _geom.ys;  }
    @property float xls() const { return _geom.xls; }
    @property float yls() const { return _geom.yls; }

    // to move an element, assign a new Geom object to it.
    @property const(Geom) geom() const { return _geom;                 }
    @property const(Geom) geom(Geom g) { reqDraw(); return _geom = g; }

    @property AlCol undrawColor() const  { return _undrawColor;     }
    @property AlCol undrawColor(AlCol c) { return _undrawColor = c; }

    @property bool hidden() const {             return _hidden;     }
    @property bool hidden(bool b) { reqDraw(); return _hidden = b; }
    @property void hide() { hidden = true;  }
    @property void show() { hidden = false; }

    void hideAllChildren() { foreach (child; _children) child.hide(); }

    @property inout(Element[]) children() inout { return _children; }

    bool isParentOf(in Element ch) const { return _geom is ch._geom.parent; }

/*  bool isMouseHere() const;
 *
 *  void reqDraw();
 *
 *      Require a redraw of the element and all its children, because some
 *      data of the element has changed.
 *
 *  void addChild   (Element e);
 *  void addChildren(Element[] ...);
 *  void rmChild    (Element e);
 *
 *      The children are a set, you can have each child only once in there.
 *      The argument must be mutable, since e.geom.parent will be set.
 *
 *  final void calc();
 *  final void work();
 *  final void draw();
 *  final void undraw();
 *
 *      draw() and undraw() assume that you've selected the correct target
 *      bitmap! In the best scenario, these are only called by gui.root.
 *      Register your important gui elements as elders or focus elements there.
 */

protected:

    // override these
    void calcSelf()   { } // do computations when GUI element has focus
    void work_self()   { } // do computations always, even when not in focus
    void drawSelf()   { } // draw to the screen, this calls geom.get_xs() etc.

/*  void undrawSelf();    // Called if appropriate before drawing. This
 *                            is implemented, you can override, don't have to.
 *
 *  static final void draw_3d_rectangle(xs, ys, xls, yls, col, col, col)
 *
 *      Used by subclasses Frame, Button, Window. The 2nd color can be transp,
 *      then that is ignored.
 *
 *      I wanted to use a Geom object for the coordinates, but that gave
 *      rounding errors with class gui.frame.Frame.
 */


private:

    Geom  _geom;
    bool  _hidden;
    AlCol _undrawColor; // if != color.transp, then undraw

    bool drawn;
    bool drawRequired;

    Element[] _children;



public:

this(Geom g)
{
    _geom        = g;
    _undrawColor = color.transp;
    drawRequired = true;
}



void addChild(Element e)
{
    assert (e !is null, "can't add null child");
    assert (_children.find!"a is b"(e) == [], "child has been added before");
    assert (e._geom.parent is null,           "child has a parent already");

    e._geom.parent = this._geom;
    _children ~= e;
}



void addChildren(Element[] elements ...)
{
    foreach (e; elements)
        addChild(e);
}



bool rmChild(Element e)
{
    assert (e !is null, "can't rm null child");
    auto found = _children.find!"a is b"(e);
    assert (found != [], "child doesn't exist, can't be removed");

    auto fe = found[0];
    assert (fe._geom.parent is this._geom,
        "gui element in child list without its parent set");
    fe._geom.parent = null;
    // remove(n) removes the item with index n. We wish to remove fe.
    _children = _children.remove(_children.length - found.length);
    return true;
}



void
reqDraw()
{
    drawRequired = true;
    foreach (child; _children)
        child.reqDraw();
}



bool isMouseHere() const
{
    if (! _hidden
     && mouseX() >= xs && mouseX() < xs + xls
     && mouseY() >= ys && mouseY() < ys + yls) return true;
    else return false;
}



final void calc()
{
    if (_hidden) return;
    foreach (child; _children) child.calc();
    calcSelf();
}



final void work()
{
    if (_hidden) return;
    foreach (child; _children) child.work();
    work_self();
}



final void draw()
{
    if (! _hidden) {
        if (drawRequired) {
            drawRequired = false;
            drawSelf();
            drawn = true;
        }
        // In the options menu, all stuff has to be undrawn first, then
        // drawn, so that rectangles don't overwrite proper things.
        // Look into this function (final void draw) below.
        foreach (c; _children) if (  c.hidden) c.draw();
        foreach (c; _children) if (! c.hidden) c.draw();
    }
    // hidden
    else
        undraw();
}



final void undraw()
{
    if (drawn) {
        if (_undrawColor != color.transp)
            undrawSelf();
        drawn = false;
    }
    drawRequired = ! _hidden;
}



void undrawSelf()
{
    al_draw_filled_rectangle(xs, ys, xs + xls, ys + yls, _undrawColor);
}



static final void
draw3DButton(
    float xs, float ys, float xls, float yls,
    in AlCol top, in AlCol mid, in AlCol bot
) {
    alias al_draw_filled_rectangle rf;

    foreach (int i; 0 .. Geom.thicks) {
        rf(xs      +i, ys    +1+i, xs    +1+i, ys+yls-1-i, top); // left
        rf(xs    +1+i, ys      +i, xs+xls-1-i, ys    +1+i, top); // top
        rf(xs+xls-1-i, ys    +1+i, xs+xls  -i, ys+yls-1-i, bot); // right
        rf(xs    +1+i, ys+yls-1-i, xs+xls-1-i, ys+yls  -i, bot); // bttom

        // draw single pixels in the corners where same-colored strips meet
        rf(xs      +i, ys      +i, xs  +1+i, ys  +1+i, top);
        rf(xs+xls-1-i, ys+yls-1-i, xs+xls-i, ys+yls-i, bot);
    }
    if (mid != color.transp) {
        // draw single pixels in the bottom-left and top-right corners
        foreach (int i; 0 .. Geom.thicks) {
            rf(xs      +i, ys+yls-1-i, xs  +1+i, ys+yls-i, mid);
            rf(xs+xls-1-i, ys      +i, xs+xls-i, ys  +1+i, mid);
        }
        // draw the large interior
        alias Geom.thicks i;
        rf(xs + i, ys + i, xs + xls - i, ys + yls - i, mid);
    }
}

}
// end class
