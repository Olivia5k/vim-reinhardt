vim-reinhardt
=============

Quickfast power tools for using vim to develop Django applications.

![Everybody loves screenshots!](http://quickfast.ninjaloot.se/img/steroids.png)

Screenshot showcasing one of the plugins navigation capabilities; Direct
navigation to models and their methods, with tab completion for everything.
Further features below:

* Easy navigation of the Django directory structure.  `gf` considers
  context and knows about templates and i18n keys.  There are
  commands defined for moving between all the key files in a Django project;
  `:Rmodel` for models, `:Rview` for views etc. Everything has tab completion
  on steroids. `:help reinhardt-navigation`

* manage.py wrapping with tab completion for the default commands and any
  command that your project defines.

* i18n awareness and helpers. When you're currently on a line containing a
  i18n translation key, the translated message will be echoed below your
  statusline. You can also use `gf` on a translation key to go to it's
  definition in the django.po file for the current language.

* Integration to other quickfast plugins in the vim universe. vim-reinhardt
  currently gain speed bonuses should you have have
  [ctrlp.vim](https://github.com/kien/ctrlp.vim) installed.

Installation
------------

If you don't have a preferred installation method, I recommend
installing [pathogen.vim](https://github.com/tpope/vim-pathogen), and
then simply copy and paste:

    cd ~/.vim/bundle
    git clone git://github.com/thiderman/vim-reinhardt.git

Once help tags have been generated, you can view the manual with
`:help reinhardt`.

FAQ
---

> I installed the plugin and started vim.  Why does only the :Reinhardt
> command exist?

This plugin cares about the current file, not the current working
directory. Edit a file from a Django project or application, that is any file
that has a parent directory that contains either a manage.py (project) or a
models.py (application).

Contributing
------------

If your [commit message sucks](http://stopwritingramblingcommitmessages.com/),
I'm not going to accept your pull request.  Tim Pope explained very politely
dozens of times that
[his general guidelines](http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html)
are absolute rules on his repositories, and I agree with them and apply them to
my repositories as well.  And please, if I ask you to change something,
`git commit --amend`.

License
-------

Copyright (c) Lowe Thiderman.  Distributed under the same terms as Vim itself.
See `:help license`.
