module basics.mainloop;

/* This class supervises all the major menus and browsers, game, and editor,
 * which are members of this class.
 *
 * To kill the game at any time, hit Shift + ESC.
 * This breaks straight out of the main loop. Unsaved data is lost.
 *
 * How to use this class: Instantiate, run main_loop() once, and then
 * exit the program when that function is done.
 */

import core.memory;

import basics.alleg5;
import basics.bench;
import basics.demo;
import game.game;
import file.log; // logging uncaught Exceptions
import hardware.display;
import hardware.keyboard;
import menu.mainmenu;
import menu.browsin;

static import gui;
static import hardware.mousecur;
static import hardware.sound;

class MainLoop {

public:

    void main_loop()
    {
        try while (true) {
            immutable last_tick = al_get_timer_count(basics.alleg5.timer);
            calc();
            if (exit) break;
            draw();

            while (last_tick == al_get_timer_count(basics.alleg5.timer))
                al_rest(0.001);
        }
        catch (Throwable thr) {
            // Uncaught exceptions, assert errors, and assert (false) should
            // fly straight out of main and terminate the program. Since
            // Windows users won't run the game from a shell, they should
            // retrieve the error message from the logfile, in addition.
            // In a release build, assert (false) crashes instead of throwing.
            Log.logf("%s:%d:", thr.file, thr.line);
            Log.log(thr.msg);
            Log.log(thr.info.toString());
            throw thr;
        }
        kill();
    }

private:

    bool exit;

    MainMenu main_menu;
    BrowserSingle brow_sin;

    Game game;

    Demo demo;
    Benchmark bench;



void
kill()
{
    if (game) {
        destroy(game);
        game = null;
    }
    if (main_menu) {
        gui.rmElder(main_menu);
        main_menu = null;
    }
    if (brow_sin) {
        gui.rmElder(brow_sin);
        destroy(brow_sin); // DTODO: check what is best here. There is a
                           // Torbit to be destroyed in the browser's preview.
        brow_sin = null;
    }
    if (demo) {
        demo = null;
    }
    if (bench) {
        bench = null;
    }
    core.memory.GC.collect();
}



void
calc()
{
    hardware.display .calc();
    hardware.keyboard.calc();
    hardware.mouse   .calc();
    gui              .calc();

    exit = exit
        || hardware.display.get_display_close_was_clicked()
        || shiftHeld() && keyTapped(ALLEGRO_KEY_ESCAPE);

    if (exit) {
        return;
    }
    else if (main_menu) {
        // no need to calc the menu, it's a GUI elder
        if (main_menu.gotoSingle) {
            kill();
            brow_sin = new BrowserSingle;
            gui.addElder(brow_sin);
        }
        else if (main_menu.gotoNetwork) {
            // DTODO: as long as networking isn't developed, this goes to demo
            kill();
            demo = new Demo;
        }
        else if (main_menu.gotoBench) {
            kill();
            bench = new Benchmark;
        }
        else if (main_menu.exitProgram) {
            exit = true;
        }
    }
    else if (brow_sin) {
        if (brow_sin.gotoGame) {
            auto lv = brow_sin.level;
            auto fn = brow_sin.filename;
            kill();
            game = new Game(lv, fn);
        }
        else if (brow_sin.gotoMainMenu) {
            kill();
            main_menu = new MainMenu;
            gui.addElder(main_menu);
        }
    }
    else if (game) {
        game.calc();
        if (game.gotoMenu) {
            kill();
            brow_sin = new BrowserSingle;
            gui.addElder(brow_sin);
        }
    }
    else if (demo) {
        demo.calc();
    }
    else if (bench) {
        bench.calc();
        if (bench.exit) {
            kill();
            main_menu = new MainMenu;
            gui.addElder(main_menu);
        }
    }
    else {
        // program has just started, nothing exists yet
        main_menu = new MainMenu;
        gui.addElder(main_menu);
    }

}



void
draw()
{
    // main_menu etc. are GUI Windows. Those have been added as elders and
    // are therefore supervised by module gui.root.

    if (game) game.draw();
    if (demo) demo.draw();
    if (bench) bench.draw();

    gui              .draw();
    hardware.mousecur.draw();
    hardware.sound   .draw();

    flip_display();
}

}
// end class
