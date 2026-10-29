#include "stdpch.h"
#include <nel/misc/event_server.h>
#include <nel/misc/event_listener.h>
#include <iostream>

int main()
{
    NLMISC::CApplicationContext context;
    NLMISC::CEventServer server;
    NLMISC::CEventListenerAsync keyboard, gui, mouse;
    keyboard.addToServer(server);
    gui.addToServer(server);
    mouse.addToServer(server);
    const NLMISC::TKey keys[] = { NLMISC::KeyLEFT, NLMISC::KeyRIGHT,
        NLMISC::KeyUP, NLMISC::KeyDOWN, NLMISC::KeyCONTROL };
    for (int round = 0; round != 3; ++round)
    {
        for (auto key : keys)
        {
            server.postEvent(new NLMISC::CEventKeyDown(key, NLMISC::noKeyButton, true, nullptr));
            server.pump();
            if (!keyboard.isKeyDown(key) || !keyboard.isKeyPushed(key)
                || !gui.isKeyDown(key) || !mouse.isKeyDown(key)) return 1;
            server.postEvent(new NLMISC::CEventKeyUp(key, NLMISC::noKeyButton, nullptr));
            server.pump();
            if (keyboard.isKeyDown(key) || gui.isKeyDown(key) || mouse.isKeyDown(key)) {
                std::cerr << "Key stuck: " << key << '\n';
                return 2;
            }
        }
        mouse.removeFromServer(server);
        mouse.addToServer(server);
    }
    server.postEvent(new NLMISC::CEventKeyDown(NLMISC::KeyCONTROL, NLMISC::ctrlKeyButton, true, nullptr));
    server.pump();
    server.postEvent(new NLMISC::CEventSetFocus(false, nullptr));
    server.pump();
    if (keyboard.isKeyDown(NLMISC::KeyCONTROL) || gui.isKeyDown(NLMISC::KeyCONTROL)
        || mouse.isKeyDown(NLMISC::KeyCONTROL)) return 3;
    std::cout << "Repeated arrow/Ctrl down-up events and listener registration: OK\n";
    mouse.removeFromServer(server);
    gui.removeFromServer(server);
    keyboard.removeFromServer(server);
}
