sub init()
    print "Scene init..."
    m.inputTask = createObject("roSGNode", "inputTask")
    m.inputTask.control = "run"
    ' Grab references to UI nodes
    m.Background   = m.top.findNode("Background")
    m.PodcastArt   = m.top.findNode("PodcastArt")
    m.AlbumPlay    = m.top.findNode("AlbumPlay")
    m.TitleLabel   = m.top.findNode("Title")
    m.AuthorLabel  = m.top.findNode("Author")
    m.SummaryLabel = m.top.findNode("Summary")

    m.AudioCurrent  = m.top.findNode("AudioCurrent")
    m.AudioDuration = m.top.findNode("AudioDuration")
    m.PlayLabel     = m.top.findNode("Play")

    ' Timer for audio playback seconds
    m.PlayTimer     = m.top.findNode("PlayTime")
    m.PlayTimer.observeField("fire", "onPlayTimerFired")

    ' Timer for rotating album art if multiple images
    m.ImageTimer    = m.top.findNode("ImageTimer")
    m.ImageTimer.observeField("fire", "onImageTimerFired")

    ' Create Audio node
    m.Audio = createObject("roSGNode", "Audio")
    m.Audio.observeField("state", "onAudioStateChange")
    m.Audio.observeField("errorCode", "onAudioErrorChange")
    m.Audio.observeField("errorMsg", "onAudioErrorChange")
    m.Audio.notificationInterval = 1

    ' Basic UI
    m.Background.uri   = ""
    m.PodcastArt.uri   = ""
    m.AlbumPlay.uri    = ""
    m.TitleLabel.text  = "My Audio Player"
    m.AuthorLabel.text = "Author/Artist Name"
    m.SummaryLabel.text= "This is a placeholder summary."
    m.AudioCurrent.text  = "0:00"
    m.AudioDuration.text = "--:--"
    m.PlayLabel.text     = "O"

    ' We'll start in a stopped state until we fetch first track
    m.isPlaying       = false
    m.playbackSeconds = 0

    ' Create & run the fetchMusicTask
    print "Creating FetchMusicTask..."
    m.fetchMusicTask = createObject("roSGNode", "FetchMusicTask")
    m.fetchMusicTask.scene = m.top
    m.fetchMusicTask.observeField("response", "onMusicTaskResponse")
    m.fetchMusicTask.response = ""
    m.fetchMusicTask.apiUrl  = "https://vgmify.com/Music/grvgm"

    print "Running fetchMusicTask..."
    m.fetchMusicTask.control = "RUN"

    ' Scene can receive remote key events
    m.top.setFocus(true)
    m.top.signalBeacon("AppLaunchComplete")
end sub

' Fired each second by the PlayTime Timer node
sub onPlayTimerFired()
    if m.isPlaying
        m.playbackSeconds += 1
        m.AudioCurrent.text = secondsToMinutes(m.playbackSeconds)
    end if
end sub

' Rotates images if we have multiple album art URIs
sub onImageTimerFired()
    if m.imageList <> invalid and m.imageList.count() > 1
        m.currentImageIndex = (m.currentImageIndex + 1) mod m.imageList.count()
        m.PodcastArt.uri    = m.imageList[m.currentImageIndex]
    end if
end sub

sub onAudioStateChange()
    print "AUDIO STATE => "; m.Audio.state
    if m.Audio.state = "finished"
        m.isPlaying = false
        m.PlayTimer.control = "stop"

        ' Fetch next random track automatically
        m.fetchMusicTask = createObject("roSGNode", "FetchMusicTask")
        m.fetchMusicTask.scene = m.top
        m.fetchMusicTask.observeField("response", "onMusicTaskResponse")
        m.fetchMusicTask.response = ""
        m.fetchMusicTask.apiUrl  = "https://vgmify.com/Music/grvgm"
        m.fetchMusicTask.control = "RUN"
    end if
end sub

sub onAudioErrorChange()
    print "AUDIO ERROR => code="; m.Audio.errorCode; ", msg="; m.Audio.errorMsg
end sub

' Called when fetchMusicTask.response changes
sub onMusicTaskResponse()
    responseStr = m.fetchMusicTask.response
    if responseStr = invalid or len(responseStr) = 0
        print "onMusicTaskResponse: empty or invalid response"
        return
    end if

    print "Got new track JSON => " + responseStr
    dataObj = ParseJSON(responseStr)
    if dataObj = invalid
        print "JSON parse failed."
        return
    end if

    ' 1) Title
    m.TitleLabel.text = dataObj["name"]

    ' 2) Artists
    artists = dataObj["artists"]
    if artists <> invalid and artists.count() > 0
        m.AuthorLabel.text = artists.join(", ")
    else
        m.AuthorLabel.text = "Unknown Artist"
    end if

    ' 3) Album, Year, Genre, Platform
    album    = dataObj["album"]
    year     = dataObj["year"]
    genArr   = dataObj["genre"]
    platArr  = dataObj["platform"]
    joinedGenre   = ""
    joinedPlatform= ""

    if genArr <> invalid and genArr.count() > 0
        joinedGenre = genArr.join(", ")
    end if

    if platArr <> invalid and platArr.count() > 0
        joinedPlatform = platArr.join(", ")
    end if

    ' Summary label: album + platform + year + genre
    ' e.g. "Album: Oddworld... (2005)\nPlatform: PS3\nGenre: Simulator, Sport"
    summaryText = "Album: " + album
    if year <> invalid and year <> ""
        summaryText = summaryText + " (" + year + ")"
    end if

    if joinedPlatform <> ""
        summaryText = summaryText + "\nPlatform: " + joinedPlatform
    end if

    if joinedGenre <> ""
        summaryText = summaryText + "\nGenre: " + joinedGenre
    end if

    m.SummaryLabel.text = summaryText

    ' 4) Duration/time
    trackTime = dataObj["time"]
    if trackTime <> invalid
        m.AudioDuration.text = trackTime
    else
        m.AudioDuration.text = "--:--"
    end if

    ' 5) Images
    m.imageList         = invalid
    m.currentImageIndex = 0
    images = dataObj["img"]
    if images <> invalid and images.count() > 0
        ' If multiple images, start rotation
        m.imageList = images
        m.currentImageIndex = 0
        m.PodcastArt.uri = images[0]
        if images.count() > 1
            m.ImageTimer.control = "start"
        else
            m.ImageTimer.control = "stop"
        end if
    else
        ' Fallback image
        m.PodcastArt.uri = "https://media.idownloadblog.com/wp-content/uploads/2018/03/Apple-Music-icon-003.jpg"
        m.ImageTimer.control = "stop"
    end if

    ' 6) Path => set to Audio node
    newPath = dataObj["path"]
    if newPath = invalid or newPath = ""
        print "No 'path' in JSON."
        return
    end if

    print "Random track path => " + newPath

    newContent = createObject("roSGNode", "ContentNode")
    newContent.url = newPath
    m.Audio.content = newContent

    ' Start playing
    m.Audio.control   = "play"
    m.isPlaying       = true
    m.playbackSeconds = 0

    ' Kick off timer for playback
    m.PlayTimer.control = "start"
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    print "Got key="; key; ", press="; press

    if press
        if (key = "play" or key = "ok" or key = "select")
            if m.isPlaying
                ' Pause
                m.Audio.control = "pause"
                m.PlayTimer.control = "stop"
                m.PlayLabel.text = "N"
                m.isPlaying = false
            else
                ' Resume
                m.Audio.control = "resume"
                m.PlayTimer.control = "start"
                m.PlayLabel.text = "O"
                m.isPlaying = true
            end if
            return true

        else if (key = "right" or key = "fastforward")
            print "User skipping track"
            m.Audio.control = "stop"
            m.isPlaying = false
            m.PlayTimer.control = "stop"
            m.ImageTimer.control = "stop"

            m.fetchMusicTask = createObject("roSGNode", "FetchMusicTask")
            m.fetchMusicTask.scene = m.top
            m.fetchMusicTask.observeField("response", "onMusicTaskResponse")
            m.fetchMusicTask.response = ""
            m.fetchMusicTask.apiUrl  = "https://vgmify.com/Music/grvgm"
            m.fetchMusicTask.control = "RUN"
            return true
        end if
    end if

    return false
end function

' Convert seconds => M:SS
function secondsToMinutes(sec as Integer) as String
    mVal = sec \ 60
    sVal = sec mod 60
    if sVal < 10
        return mVal.toStr() + ":0" + sVal.toStr()
    else
        return mVal.toStr() + ":" + sVal.toStr()
    end if
end function
