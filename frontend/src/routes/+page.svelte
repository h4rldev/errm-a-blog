<script>
import { SvelteDate } from "svelte/reactivity";
import Cell from "$components/Cell.svelte";
import Header from "$components/Header.svelte";
import Heading from "$components/Heading.svelte";
import Link from "$components/Link.svelte";
import ListenBrainz from "$components/ListenBrainz.svelte";

const birthDate = new Date("2005-09-02");
const now = new SvelteDate();
$effect(() => {
	const interval = setInterval(() => {
		now.setTime(Date.now());
	}, 1);
	return () => clearInterval(interval);
});

const age = $derived(
	((now.getTime() - birthDate.getTime()) / 31556926000).toFixed(2),
);
</script>

<Header />

<main>
  <section>
    <Cell>
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
    <Cell>
      <ListenBrainz />
    </Cell>

  </section>
</main>
