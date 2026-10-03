import { browser } from "$app/environment";

const create_theme_store = () => {
  const get_initial_theme = (): "light" | "dark" => {
    if (browser) {
      if (document.documentElement.classList.contains("dark")) return "dark";
      const stored = localStorage.getItem("theme") as "light" | "dark" | null;
      if (stored) return stored;
    }
    return "light";
  };

  let theme = $state<"light" | "dark">(get_initial_theme());
  return {
    get value() {
      return theme;
    },
    set value(new_theme: "light" | "dark") {
      theme = new_theme;
      if (browser) {
        localStorage.setItem("theme", new_theme);
        document.documentElement.classList.toggle("dark", new_theme === "dark");
      }
    },
    toggle() {
      this.value = this.value === "light" ? "dark" : "light";
    },
  };
};

export const theme = create_theme_store();
