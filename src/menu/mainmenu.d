module menu.mainmenu;

/* This is shown after the game has initialized everything.
 * When the game is run for the first time, the small dialogues asking
 * for language and name are shown first instead, and only then this.
 *
 * DTODO: the button "bench" should be removed at some point.
 */

import basics.alleg5;  // drawing bg to screen
import basics.globals; // title bar text
import basics.versioning;
import basics.user;
import graphic.gralib; // menu background
import file.language;
import gui;

class MainMenu : Window {

    @property bool gotoSingle()  { return single .execute; }
    @property bool gotoNetwork() { return network.execute; }
    @property bool gotoReplays() { return replays.execute; }
    @property bool gotoOptions() { return options.execute; }
    @property bool gotoBench()   { return bench  .execute; }
    @property bool exitProgram() { return _exit  .execute; }

private:

    TextButton single;
    TextButton network;
    TextButton replays;
    TextButton options;
    TextButton bench;
    TextButton _exit;

    Label versioning;
    Label website;



public this()
{
    immutable butXlg = 200; // large button length
    immutable butSlg =  90; // small button length
    immutable butYlg =  40; // any button's y length
    immutable butSpg =  20; // spacing

    TextButton buttext_height(Geom.From from, int height)
    {
        int heightg = Window.titleYlg + butSpg + height*(butYlg+butSpg);
        return new TextButton(new Geom(
            height == 2 ? butSpg : 0,         heightg,
            height == 2 ? butSlg : butXlg,   butYlg, from));
    }

    super(new Geom(0, 0,
        butXlg     + butSpg * 2,                  // 80 = labels and space
        butYlg * 4 + butSpg * 4 + Window.titleYlg + 80, Geom.From.CENTER),
        basics.globals.nameOfTheGame);

    single  = buttext_height(Geom.From.TOP,       0);
    network = buttext_height(Geom.From.TOP,       1);
    replays = buttext_height(Geom.From.TOP_LEFT , 2);
    options = buttext_height(Geom.From.TOP_RIGHT, 2);
    _exit   = buttext_height(Geom.From.TOP,       3);

    single .text = Lang.browserSingleTitle.transl;
    network.text = "Demo (Shift+ESC to exit)"; // winLobbyTitle.transl DTODO
    replays.text = Lang.browserReplayTitle.transl;
    options.text = Lang.option_title.transl;
    _exit  .text = Lang.commonExit.transl;

    single .hotkey = basics.user.keyMenuMainSingle;
    network.hotkey = basics.user.keyMenuMainNetwork;
    replays.hotkey = basics.user.keyMenuMainReplays;
    options.hotkey = basics.user.keyMenuMainOptions;
    _exit  .hotkey = basics.user.keyMenuExit;

    import std.conv;
    versioning = new Label(new Geom(0, 40, xlg, 20, Geom.From.BOTTOM),
        transl(Lang.commonVersion) ~ " " ~ gameVersion().toString());

    website    = new Label(new Geom(0, 20, xlg, 20, Geom.From.BOTTOM),
        basics.globals.homepageURL);

    addChildren(single, network, replays, options, _exit,
        versioning, website);

    bench = new TextButton(new Geom(0, -butYlg - butSpg,
                           560, single.ylg, Geom.From.TOP));
    bench.text = "Benchmark! Runs for about 2 minutes. Click here!";
    this.addChild(bench);
}
// end this()



protected override void
drawSelf()
{
    auto bg = getInternal(fileImageMenuBackground);
    if (bg && bg.valid)
        al_draw_scaled_bitmap(bg.albit,
         0, 0, bg.xl,           bg.yl,
         0, 0, Geom.screenXls, Geom.screenYls, 0);
    else
        torbit.clearToBlack();

    super.drawSelf();
}

}
// end class
