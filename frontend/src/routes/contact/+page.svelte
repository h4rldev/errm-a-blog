<script>
import Cell from "$components/Cell.svelte";
import Heading from "$components/Heading.svelte";
import Link from "$components/Link.svelte";
</script>

<main>
  <Cell title="contact">
    <Heading level="2">
      Contact me!
    </Heading>

    <p>
      Whether you want to chat, commission, befriend, ask for help, or just want to say hi, you can reach me through:
    </p>
    
    <Cell title="Messaging Software">
      <ul class="list-disc list-inside">
        <li>Matrix: <Link href="https://matrix.to/#/@h4rl:h4rl.dev">@h4rl:h4rl.dev</Link></li>
        <li>Discord: <Link href="https://discord.com/users/275689969601871882">@h4rl</Link></li>
        <li>Fluxer: <code>@h4rl#2893</code></li>
        <li>Signal: <code>h4rl.01</code></li>
      </ul>
    </Cell>
    <Cell title="Email">
      <p> My email address is ("encrypted" to avoid bots): </p>
      <p> <code>contact [ at ] h4rl [ dot ] dev</code> </p>
    </Cell>
    <Cell title="Social Media">
      <ul class="list-disc list-inside">
        <li>GitHub: <Link href="https://github.com/h4rldev">h4rldev</Link></li>
        <li>Codeberg: <Link href="https://codeberg.org/h4rl">h4rl</Link></li>
        <li>Bluesky: <Link href="https://bsky.app/profile/h4rl.dev">@h4rl.dev</Link></li>
        <li>Twitter: <Link href="https://twitter.com/rmdesktop">@rmdesktop</Link></li>
      </ul>
    </Cell>
  </Cell>
</main>
