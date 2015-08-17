# Development Style Guide
This development guide tries to show you how we style the code of OBS.

## Models
All the **ActiveRecord::Base** models should use the same structure to be easy to follow for everyone. We have
overwritten the template for model, so you can just use Rails::Generators like that:

  ```
  rails generate model Dog
  ```

For a better comprehension [here](model_template_example.rb) you have an example with code in it's place.

## Scaffold Controllers

All the Controllers should use the same structure to be easy to follow for everyone. We have
overwritten the template for controllers too, so you can just use Rails::Generators like that:

  ```
  rails generate scaffold_controller Webui::Dog
  ```

Have in mind that namespaced controllers that uses non-namespaced models should be created as follows:

  ```
  rails generate scaffold_controller Webui::Dog --model-name=Dog
  ```

Also to have in mind is that the template is based on **Pundit policies** and you will have to create it.

For a better comprehension [here](controller_template_example.rb) you have an example with code in it's place.
