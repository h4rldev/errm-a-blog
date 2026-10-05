<script lang="ts">
 import { SvelteDate } from "svelte/reactivity";
 import Cell from "$components/Cell.svelte";
 import Heading from "$components/Heading.svelte";
 import Link from "$components/Link.svelte";
 import ListenBrainz from "$components/ListenBrainz.svelte";
 import Meta from "$components/Meta.svelte";
 import Marquee, { type Badge } from "$components/Marquee.svelte";
 
 const birthDate = new Date("2005-09-02");
 const now = new SvelteDate();

 $effect(() => {
   const interval = setInterval(() => {
     now.setTime(Date.now());
   }, 1000);
   return () => clearInterval(interval);
 });

 const age = $derived(
   ((now.getTime() - birthDate.getTime()) / 31556926000).toFixed(2),
 );

 const friends: Badge[] = [
   { src: "/badges/h4rl.png", href: "https://h4rl.dev", alt: "h4rl.dev" },
   { src: "/badges/friends/hrtowii.png", href: "https://hrtowii.nekoweb.org", alt: "hrtowii.nekoweb.org" },
   { src: "/badges/friends/at0m.gif", href: "https://at0m.firebomb.ing", alt: "at0m.firebomb.ing" },
   { src: "https://dane.gg/assets/img/buttons/88x31/button.gif", href: "https://dane.gg", alt: "dane.gg" },
   { src: "/badges/friends/jesx.gif", href: "https://anemoia.moe/", alt: "anemoia.moe" },
 ];

 const random: Badge[] = [
   { src: "/badges/random/erlang.png", href: "https://erlang.org", alt: "erlang.org" },
   { src: "/badges/random/svelte.png", href: "https://svelte.dev", alt: "svelte.dev" },
   { src: "/badges/random/madewithemacs.png", href: "https://www.gnu.org/software/emacs/", alt: "Made with GNUemacs" },
   { src: "/badges/random/nixos.gif", href: "https://nixos.org", alt: "nixos.org" },
   { src: "/badges/random/mullvad.png", href: "https://mullvad.net", alt: "mullvad.net" },
   { src: "/badges/random/helium.png", href: "https://helium.computer", alt: "helium.computer" },
   { src: "/badges/random/jellyfin.png", href: "https://jellyfin.org", alt: "jellyfin.org" },
   { src: "/badges/random/listenbrainz.webp", href: "https://listenbrainz.org", alt: "listenbrainz.org" },
   { src: "/badges/random/bitwarden.gif", href: "https://bitwarden.com", alt: "bitwarden.com" },
   { src: "/badges/random/queercoded.png", alt: "you're tellimg me a queer coded this"},
   { src: "/badges/random/meow.gif", alt: "meow :3" },
   { src: "/badges/random/enbypan.png", alt: "Non-Binary Pansexual" },
   { src: "/badges/random/transrights.png", alt: "Trans rights!" },
   { src: "/badges/random/palestine.gif", href: "https://arab.org", alt: "Free Palestine!"},
 ];
</script>

<Meta title="Home" path="/" />
<main>
  <Cell title="about">
    <Heading level="1">
      Hello, and welcome!
    </Heading>

    <p class="mb-6">
      I'm a {age} year old queer hobbyist, wannabe professional programmer,
      rhythm game player, audiophile, and open source contributor
      based in <Link href="https://kagi.com/maps/info?q=Karlstad&ll=59.381292,13.401915&id=IpZy42oCU11uJhNcwv8nwLKRLYAvBQvXVnQVt2_K2Qlg2EfeyR5D19evsHE1KSBzv_ydsB5IzVO9DM2CnqpLD4qcyvPfrzERL3OA94ZjNWHN9Nfear5_EDuW00nA4aXVBlEgZtoCyoo9TnOfLL3TPhWjPSULoKNs3WXTMcXfook#10.445/59.381292/13.401915">Karlstad, Sweden</Link>.
    </p>

    <p>
      Some languages I'm familiar with are
      <Link href="https://c-language.org/">C</Link>,
      <Link href="https://erlang.org/">Erlang</Link> (Hey, this website is hosted on Erlang!),
      <Link href="https://www.rust-lang.org/">Rust</Link>, and
      <Link href="https://www.typescript.org/">TypeScript</Link>.
    </p>

    <Heading level="2">
      Some other information about me!
    </Heading>
    <ul class="list-disc list-inside mb-6">
      <li>I'm pansexual and non-binary.</li>
      <li>I use <code>any/all</code> pronouns.</li>
      <li>I never use streaming services for music.</li>
      <li>I tend to prefer programming in languages that give me freedom to reinvent wheels, even if that feels inconvenient.</li>
      <li>I primarily use <Link href="https://codeberg.org">Codeberg</Link> for hosting my code, since GitHub has gotten more and more annoying.</li>
    </ul>

    <Heading level="3">
      Footnotes
    </Heading>
    <p>
      Any and every opinion is my own, and not on the behalf on any employer now or in the future. <br/>

      I also have a Ko-fi page, where you can support me, <Link href="https://ko-fi.com/h4rl3h">here</Link>.
    </p>
  </Cell>
  <Cell title="Buttons">
    <Marquee badges={friends} duration={5} />
    <Marquee badges={random} duration={10} />
  </Cell>
  <Cell title="listening">
    <ListenBrainz refresh_interval={7500} />
  </Cell>
</main>
