module menu.menubg;

import basics.globals;
import basics.alleg5;
import graphic.internal;
import gui;

class MenuWithBackground : Window {
public:
    this(Geom g, string ti = "") { super(g, ti); }

protected:
    override void drawSelf()
    {
        auto bg = getInternal(fileImageMenuBackground);
        if (bg && bg.valid)
            al_draw_scaled_bitmap(bg.albit, 0, 0, bg.xl, bg.yl,
                0, 0, Geom.screenXls, Geom.screenYls, 0);
        else
            torbit.clearToBlack();
        super.drawSelf();
    }
}
