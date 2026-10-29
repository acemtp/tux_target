#include "stdpch.h"
#include <nel/sound/u_audio_mixer.h>
#include <nel/sound/u_source.h>
#include <chrono>
#include <thread>
#include <memory>
#include <iostream>

int main(int argc, char **argv)
{
    if (argc != 2) return 1;
    NLMISC::CApplicationContext context;
    const std::string root = argv[1];
    NLMISC::CPath::addSearchPath(root + "/client/data/sound", true, false);
    NLMISC::CPath::addSearchPath(root + "/runtime-macos-client/audio", true, false);
    const std::string cache = root + "/runtime-macos-client/cache/audio-check/";
    NLMISC::CFile::createDirectoryTree(cache);
    std::unique_ptr<NLSOUND::UAudioMixer> mixer(NLSOUND::UAudioMixer::createAudioMixer());
    mixer->setPackedSheetOption(cache, true);
    NLSOUND::UAudioMixer::buildSampleBank(root + "/client/data/sound", cache, "mtp_target");
    NLMISC::CPath::addSearchPath(cache, false, false);
    mixer->init(16, false, false, nullptr, true, NLSOUND::UAudioMixer::DriverOpenAl, true);
    mixer->loadSampleBank(false, "mtp_target");
    const char *names[] = {"open", "close", "impact", "ready"};
    for (auto name : names)
    {
        std::unique_ptr<NLSOUND::USource> source(mixer->createSource(NLMISC::CStringMapper::map(name)));
        if (!source) { std::cerr << "Missing effect: " << name << '\n'; return 2; }
        source->setSourceRelativeMode(true);
        source->setGain(0.1f);
        source->play();
        if (!source->isPlaying()) return 3;
        source->stop();
        std::cout << "Effect loaded and started: " << name << '\n';
    }
    mixer->setMusicVolume(0.1f);
    if (!mixer->playMusic(root + "/client/data/sound/zik.ogg", 0, false, false)) return 4;
    for (int i = 0; i < 8; ++i)
    {
        mixer->update();
        std::this_thread::sleep_for(std::chrono::milliseconds(25));
    }
    if (mixer->isMusicEnded()) return 5;
    mixer->stopMusic(0);
    std::cout << "OGG music playback started: OK\n";
}
