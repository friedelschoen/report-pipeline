## Options

- Lists are denoted as `type[]`
- Objects are denoted as `type -> type`

| Name            | Type                                                | Description                                                          |
| --------------- | --------------------------------------------------- | -------------------------------------------------------------------- |
| documentclass   | `article` / `report` / `book` / `slides` / `letter` | The kind of document you are writing                                 |
| packages        | string[]                                            | Names of `\usepackage` you want to use                               |
| packageoptions  | string -> (string/string[]/string->string)          | Options for packages in `packages`                                   |
| title           | string                                              | Title of this document                                               |
| subtitle        | string                                              | Subtitle of this document                                            |
| author          | string                                              | Author of this document                                              |
| date            | string                                              | Date of this document (defaults to `\today`)                         |
| geometry        | string / string[]                                   | Geometry and paramters of this document                              |
| fontsize        | string                                              | Size of regular text                                                 |
| mainfont        | string                                              | Fontname of regular text                                             |
| monofont        | string                                              | Fontname of monospaced text                                          |
| monofontoptions | string / string[] / (string->string)                | Options to monospaces text                                           |
| sansfont        | string                                              | Fontname of serif text                                               |
| sansfontoptions | string / string[] / (string->string)                | Options to serif text                                                |
| numbersections  | bool                                                | Whether headers and subheaders should be numered                     |
| newcommands     | string -> string                                    | LaTeX commands to define                                             |
| header-includes | string / string[]                                   | Commands to include in preamble                                      |
| colors          | string -> hexcolor (without leading `#`)            | Colors which can be reused in title, textcolor etc.                  |
| titlepagecolor  | string                                              | Background color of titlepage                                        |
| titlepagetext   | string                                              | Text color of titlepage                                              |
| titletable      | string[][]                                          | Table to include on titlepage<sup>1</sup>                            |
| confidant       | bool                                                | Whether this document is confidant, a note is left in titlepage      |
| cover           | bool                                                | Whether a coverpage should be inserted                               |
| pagebeforecover | bool                                                | Whether an empty page should be inserted between titlepage and cover |
| covertable      | string[][]                                          | Table to include on cover<sup>1</sup>                                |

<sup>1</sub> Tables must be defined as list of string-pairs