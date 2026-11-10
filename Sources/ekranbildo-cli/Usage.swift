let usage = """
    ekranbildo-cli <scene.json> [options]
    ekranbildo-cli corpus <directory> [options]
    ekranbildo-cli detect <screenshot.png> [options]
    ekranbildo-cli capture [list] [options]
    ekranbildo-cli annotate <screenshot.png> --point <x,y:label> ... [options]
    ekranbildo-cli stitch <frame.png> ... [options]
    ekranbildo-cli record [options]
    ekranbildo-cli redact <screenshot.png> [options]
    ekranbildo-cli compare <directory> [options]
    ekranbildo-cli camera <events.json> [options]
    ekranbildo-cli render-video <frames-dir> [options]
    ekranbildo-cli synthesise <scene.json> [options]
    ekranbildo-cli replay <bundle.ekranbildotrace> [options]
    ekranbildo-cli bisect <bundle.ekranbildotrace> --versions <a,b,c> --run <command>

    Renders a scene, runs every scene in a directory, reports what detection
    finds in a screenshot, or photographs the screen. Geometry is in points. Annotations without a placement
    are solved for.

    Render options:
      --png <path>         write a rendered image
      --svg <path>         write a vector rendering
      --trace <path>       write the deterministic trace
      --report <path>      write the layout inspector page
      --bundle <path>      write a replay bundle: the scene, this build, and
                           what this build decided
      --scale <n>          pixels per point for --png (default 1)

    Corpus options:
      --sheet <path>       write the contact sheet
      --scoreboard <path>  write the machine-comparable measurements

    Capture options:
      list                 report the displays and windows and stop
      --display <id>       which display (default: the first)
      --window <id>        one window instead of a display
      --png <path>         write the captured picture
      --report <path>      write what detection made of it

    Annotate options:
      --point <x,y:label>  point at something and say what it is; repeatable
      --capture-scale <n>  pixels per point in the screenshot (default 1)
      --text no            find shapes only, without reading the words
      --beautify <points>  put room, a background and a shadow around it
      --steps yes          number the points in the order they were given
      --reading <name>     leftToRight (default) or rightToLeft
      --png <path>         write the annotated picture
      --svg <path>         write a vector rendering
      --report <path>      write the layout inspector page
      --trace <path>       write the deterministic trace

    Stitch options:
      --png <path>         write the joined page
      --report <path>      write what was found, including uncertain joins

    Record options:
      --seconds <n>        how long to record (default 3)
      --display <id>       which display (default: the first)
      --summary <path>     write what was recorded
      --frames <dir>       write every frame as a picture
      --scale <n>          pixels per point to record at (default 1)

    Redact options:
      --style <name>       pixelate (default), solid or blur
      --png <path>         write the covered picture
      --report <path>      write what was found and what was done

    Compare options:
      --page <path>        write a page of side-by-side questions to answer
      --answers <path>     answers to check the solver against
      --report <path>      write how often the solver agreed
      --questions <n>      how many to ask (default 40)
      --tolerance <n>      what counts as no difference (default 0.05)

    Camera options:
      --keyframes <path>   write where the camera looks and when
      --report <path>      write the path drawn over the picture

    Render-video options:
      --events <path>      camera events to follow
      --video <path>       write the finished video
      --keyframes <path>   write where the camera looked and when
      --fps <n>            frames a second (default 30)
      --frames <dir>       write the finished frames as pictures

    Synthesise options:
      --out <path>         write the scene with nothing real left in it
      --report <path>      write what was replaced
      --gif <path>         write an animated picture of it
      --trace <path>       a trace to make safe as well
      --trace-out <path>   where the safe trace goes; required with --trace,
                           because the original is never written over

    Replay options:
      --answer <path>      write just this build's answer, one line per
                           annotation, which is what bisect compares
      --record yes         write this build's answer back into the bundle
                           instead of comparing against what is there

    Bisect options:
      --versions <a,b,c>   the builds to search, oldest first
      --run <command>      what asks one build for its answer. {version} and
                           {bundle} are filled in, and it has to print what
                           `replay --answer -` would write

    Detect options:
      --detector <name>    regions (default), vision, or all
      --elements <path>    write a line per detected element
      --report <path>      write the rectangles drawn back over the picture
      --snapshot <path>    write the whole answer, for replaying later
      --snap <x,y>         resolve a click into its ladder of readings
    """

#if EKRANBILDO_TESTHOOKS
    let hooksUsage = """

        ekranbildo-cli hooks [scene.json]

        Serves the test hook channel on standard input and output, so that a test
        can send events and ask for the scene instead of clicking at a coordinate
        and photographing the result. A message is a name, a length in bytes, a
        newline, and that many bytes; a reply is the same, beginning with ok or
        failed.

          scene.dump          the document, in the format it is saved in
          input.replay        a JSON array of InputEvent, applied in order
          clock.read          the clock, without moving it
          clock.advance       {"nanoseconds": n}, forwards only
          trace.export        what this session has done

        Debug builds only. Scripts/verify-artifact.sh checks that none of it is in
        a release binary, and that all of it is in a debug one.
        """
#endif
