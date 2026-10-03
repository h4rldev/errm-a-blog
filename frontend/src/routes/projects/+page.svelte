<script>
 import Cell from "$components/Cell.svelte";
 import Heading from "$components/Heading.svelte";
 import Link from "$components/Link.svelte";
 import Meta from "$components/Meta.svelte";
 
 const projects = [
   {
     name: "Errm... A blog?",
     desc: "A simple blog written in Erlang/OTP 28 with my own library ecosystem, that uses Svelte + TailwindCSS for the frontend.",
     links: [
       { label: "Source", href: "https://codeberg.org/h4rl/errm-A-blog", text: "codeberg.org/h4rl/errm-A-blog" },
       { label: "Preview", href: "/", text: "You're looking at it!" },
     ]
   },
   {
     name: "Errm... HTTP!",
     desc: "A HTTP/1.1 server written in Erlang/OTP 28, with support for middleware, compression, secrets and easy cookie handling.",
     links: [
       { label: "Source", href: "https://codeberg.org/h4rl/errm-HTTP", text: "codeberg.org/h4rl/errm-HTTP" },
     ]
   },
   {
     name: "Errm... SQLite!",
     desc: "A SQLite wrapper written in Erlang/OTP 28, with support for easy migrations, easy querying with bindings and prepared statements.",
     links: [
       { label: "Source", href: "https://codeberg.org/h4rl/errm-SQLite", text: "codeberg.org/h4rl/errm-SQLite" },
     ]
   },
   {
     name: "Errm... JSON!",
     desc: "A stateless JSON parser and writer written in Erlang/OTP 28, with support for pretty writing, and map ordering.",
     links: [
       { label: "Source", href: "https://codeberg.org/h4rl/errm-JSON", text: "codeberg.org/h4rl/errm-JSON" },
     ]
   },
   {
     name: "bread",
     desc: "A lightweight X11/Wayland platform-layer you can bind your own renderer to! With input event tracking, resize tracking, mouse tracking, and key press conversion.",
     links: [
       { label: "Source", href: "https://codeberg.org/h4rl/bread", text: "codeberg.org/h4rl/bread" },
     ]
   },
   {
     name: "butter",
     desc: "A small, experimental Vulkan renderer that you can pass XCB/Wayland surfaces to, with async texture uploads, and an easy drawing API.",
     links: [
       { label: "Source", href: "https://codeberg.org/h4rl/butter", text: "codeberg.org/h4rl/butter" },
     ]
   },
   {
     name: "cheese",
     desc: "An immediate-mode UI toolkit designed to be easy to work with, to create easy to comprehend UI, bindable with any renderer and platform-layer you'd like!",
     links: [
       {  label: "Source", href: "https://codeberg.org/h4rl/cheese", text: "codeberg.org/h4rl/cheese" },
     ]
   }
 ];
</script>

<Meta title="Projects" path="/projects/" />
<main>
  <Cell title="introduction">
    <Heading level="2">
      I work on a lot of projects! <br/>
      <sub>but don't worry this page will just mention a few of them.</sub>
    </Heading>
    <p>I tend to only really write projects that solves a problem I have, or what seems like fun to me, but thats usually cause nobody really asks me to implement something that isn't either a large pain or gigantic, so... *clears throat* anyway, let me show you some projects.</p>
  </Cell>

  {#each projects as project}
    <Cell title="projects">
      <Heading level="3">{project.name}</Heading>
      <p>{project.desc}</p>
      <Cell title="links">
        <ul>
          {#each project.links as link}
            <li>{link.label}: <Link href={link.href}>{link.text}</Link></li>
          {/each}
        </ul>
      </Cell>
    </Cell>
  {/each}

  <Cell title="projects">
    <Heading level="3">More Projects</Heading>
    <p>I have more projects, but I dont really need to list them here, otherwise this page would get massive haha. Although feel free to check out my Codeberg and GitHub below if you're more curious.</p>
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
