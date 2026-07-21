<script>
import Cell from "$components/Cell.svelte";
import Heading from "$components/Heading.svelte";
import Link from "$components/Link.svelte";
</script>


<main>
  <Cell title="introduction">
    <Heading level="2">
      I work on a lot of projects! <br/>
      <sub class="text-xs font-normal">
      but don't worry this page will just mention a few of them.
      </sub>
    </Heading>
    <p>
      I tend to only really write projects that solves a problem I have, or what seems like fun to me, but thats usually cause nobody really asks me to implement something that isn't either a large pain or gigantic, so... *clears throat* anyway, let me show you some projects.
    </p>
  </Cell>
  <Cell title="projects">
    <Heading level="3">
      Errm... A blog?
    </Heading>
    <p>
      A simple blog written in Erlang/OTP 28 with my own library ecosysten, that uses Svelte + TailwindCSS for the frontend. <br />

    </p>
    <Cell title="links">
      <ul>
        <li>Source: <Link href="https://codeberg.org/h4rl/errm-A-blog">codeberg.org/h4rl/errm-A-blog</Link></li>
        <li>Preview: <Link href="/">You're looking at it!</Link></li>
      </ul>
    </Cell>
  </Cell>
  <Cell title="projects">
    <Heading level="3">
      Errm... HTTP!
    </Heading>
    <p>
      A HTTP/1.1 server written in Erlang/OTP 28, with support for middleware, compression, secrets and easy cookie handling. <br />
    </p>
    <Cell title="links">
      <ul>
        <li>Source: <Link href="https://codeberg.org/h4rl/errm-HTTP">codeberg.org/h4rl/errm-HTTP</Link></li>
      </ul>
    </Cell>
  </Cell>
  <Cell title="projects">
    <Heading level="3">
      Errm... SQLite!
    </Heading>
    <p>
      A SQLite wrapper written in Erlang/OTP 28, with support for easy migrations, easy querying with bindings and prepared statements. <br />
    </p>
    <Cell title="links">
      <ul>
        <li>Source: <Link href="https://codeberg.org/h4rl/errm-SQLite">codeberg.org/h4rl/errm-SQLite</Link></li>
      </ul>
    </Cell>
  </Cell>
  <Cell title="projects">
    <Heading level="3">
      Errm... JSON!
    </Heading>
    <p>
      A statless JSON parser and writer written in Erlang/OTP 28, with support for pretty writing, and map ordering. <br />
    </p>
    <Cell title="links">
      <ul>
        <li>Source: <Link href="https://codeberg.org/h4rl/errm-JSON">codeberg.org/h4rl/errm-JSON</Link></li>
      </ul>
    </Cell>
  </Cell>
  <Cell title="projects">
    <Heading level="3">
      bread
    </Heading>
    <p>
      A lightweight X11/Wayland platform-layer you can bind your own renderer to! With input event tracking, resize tracking, mouse tracking, and key press conversion. <br />
    </p>
    <Cell title="links">
      <ul>
        <li>Source: <Link href="https://codeberg.org/h4rl/bread">codeberg.org/h4rl/bread</Link></li>
      </ul>
    </Cell>
  </Cell>
  <Cell title="projects">
    <Heading level="3">
      butter
    </Heading>
    <p>
      A small, experimental Vulkan renderer that you can pass XCB/Wayland surfaces to, with async texture uploads, and an easy drawing API. <br />
    </p>
    <Cell title="links">
      <ul>
        <li>Source: <Link href="https://codeberg.org/h4rl/butter">codeberg.org/h4rl/butter</Link></li>
      </ul>
    </Cell>
  </Cell>
  <Cell title="projects">
    <Heading level="3">
      More Projects
    </Heading>

    <p>
      I have more projects, but I dont really need to list them here, otherwise this page would get massive haha.

      Although feel free to check out my Codeberg and GitHub below if you're more curious.
    </p>
    <Cell title="links">
      <ul>
        <li>Codeberg: <Link href="https://codeberg.org/h4rl">codeberg.org/h4rl</Link></li>
        <li>GitHub: <Link href="https://github.com/h4rldev">github.com/h4rldev</Link></li>
      </ul>
    </Cell>
  </Cell>
</main>


<style>
  @reference '$tailcss';

  sub {
    @apply text-xs text-(--color-subtext);
  }

</style>
