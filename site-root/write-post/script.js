const endpoints = {
  create_post: "/api/posts",
};

const forms = [
  { form: document.getElementById("create-post-form"), endpoint: endpoints.create_post }
];

const form_data_to_json = (Data) => {
  const obj = {};
  for (const [key, value] of Data.entries()) {
    if (key === 'tags' && typeof value === 'string') {
      const tagsArray = value.split(',').map(s => s.trim()).filter(Boolean);
      obj[key] = tagsArray;
      continue;
    }

    if (obj.hasOwnProperty(key)) {
      if (Array.isArray(obj[key])) {
        obj[key].push(value);
      } else {
        obj[key] = [obj[key], value];
      }
    } else {
      obj[key] = value;
    }
  }

  return obj;
};


const handle_form_submit = async (e, endpoint) => {
  e.preventDefault();

  const form = e.currentTarget;
  const form_data = new FormData(form);
  const json = form_data_to_json(form_data);

  try {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(json)
    });

    if (!response.ok) {
      const text = await response.text();
      throw new Error(`Server error: ${response.status} - ${text}`);
    }

    const result = await response.json();
    console.log(`${form.id} success: `, result);
  } catch (error) {
    console.error(`${form.id} error: `, error);
  }
};

forms.forEach(({form, endpoint}) => {
  form.addEventListener("submit", e => handle_form_submit(e, endpoint));
});

