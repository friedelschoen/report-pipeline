package main

import (
	"fmt"
	htmltemplate "html/template"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"
	"text/template"

	"github.com/spf13/pflag"
	"gopkg.in/yaml.v3"
)

type Template interface {
	Execute(wr io.Writer, data any) error
	ExecuteTemplate(wr io.Writer, name string, data any) error
}

var (
	searchDirs = pflag.StringSliceP("search", "I", nil, "search for templates here")
	bodyPath   = pflag.StringP("body", "b", "", "use `file` instead of stdin as body")
	outputPath = pflag.StringP("output", "o", "", "output to `file` instead of stdout")
	define     = pflag.StringSliceP("define", "D", nil, "define value")
	undefine   = pflag.StringSliceP("undefine", "U", nil, "define value")
	outputHTML = pflag.BoolP("html", "w", false, "use HTML-templates")
)

func readOptions(todo []string) (options map[string]any, _ error) {
	for len(todo) > 0 {
		currentpath := todo[0]
		todo = todo[1:]

		optionsFile, err := os.Open(currentpath)
		if err != nil {
			return nil, fmt.Errorf("unable to open `%s`: %w", currentpath, err)
		}
		defer optionsFile.Close()

		if err := yaml.NewDecoder(optionsFile).Decode(&options); err != nil {
			return nil, fmt.Errorf("unable to read `%s`: %w", currentpath, err)
		}

		if incl, ok := options["include"]; ok {
			currentdir := filepath.Dir(currentpath)
			switch incl := incl.(type) {
			case string:
				p, err := filepath.Rel(currentdir, incl)
				if err != nil {
					return nil, fmt.Errorf("unable to locate file %q, relative to %q: %w", incl, currentpath, err)
				}
				todo = append(todo, p)
			case []any:
				for _, inc := range incl {
					if inc, ok := inc.(string); ok {
						p, err := filepath.Rel(currentdir, inc)
						if err != nil {
							return nil, fmt.Errorf("unable to locate file %q, relative to %q: %w", inc, currentpath, err)
						}
						todo = append(todo, p)
					}
				}
			}
			delete(options, "include")
		}
	}
	return
}

func defaultValue(def, v any) any {
	switch x := v.(type) {
	case nil:
		return def
	case string:
		if x == "" {
			return def
		}
	}
	return v
}

func joinAny(sep string, v any) string {
	switch x := v.(type) {
	case []string:
		return strings.Join(x, sep)
	case []any:
		out := make([]string, 0, len(x))
		for _, it := range x {
			out = append(out, fmt.Sprint(it))
		}
		return strings.Join(out, sep)
	case nil:
		return ""
	default:
		return fmt.Sprint(v)
	}
}

func writeOptions(out *strings.Builder, options any) {
	switch options := options.(type) {
	case string:
		out.WriteString(options)
	case []any:
		for i, o := range options {
			if i > 0 {
				out.WriteByte(',')
			}
			writeOptions(out, o)
		}
	case map[string]any:
		i := 0
		for key, value := range options {
			if i > 0 {
				out.WriteByte(',')
			}
			out.WriteString(key)
			out.WriteByte('=')
			writeOptions(out, value)
			i++
		}
	default:
		panic(fmt.Sprintf("%T", options))
	}
}

func usePackage(packages []any, options map[string]any) string {
	var out strings.Builder

	for _, anypkgname := range packages {
		pkgname := anypkgname.(string)
		if opt, ok := options[pkgname]; ok {
			fmt.Fprint(&out, "\\usepackage[")
			writeOptions(&out, opt)
			fmt.Fprintf(&out, "]{%s}\n", pkgname)
		} else {
			fmt.Fprintf(&out, "\\usepackage{%s}\n", pkgname)
		}
	}
	return out.String()
}

func main() {
	pflag.Parse()

	if pflag.NArg() < 2 {
		pflag.Usage()
		os.Exit(1)
	}

	templPath := pflag.Arg(0)
	optionsPaths := pflag.Args()[1:]

	*searchDirs = append(*searchDirs, ".", filepath.Dir(templPath))

	options, err := readOptions(optionsPaths)
	if err != nil {
		log.Fatalln(err)
	}

	bodyFile := os.Stdin
	if *bodyPath != "" {
		bodyFile, err = os.Open(*bodyPath)
		if err != nil {
			log.Fatalf("unable to open `%s`: %v", *bodyPath, err)
		}
	}
	defer bodyFile.Close()

	body, err := io.ReadAll(bodyFile)
	if err != nil {
		log.Fatalln("unable to read from stdin: ", err)
	}

	options["body"] = string(body)

	for _, pair := range *define {
		key, value, ok := strings.Cut(pair, "=")
		if ok {
			options[key] = value
		} else {
			options[key] = true
		}
	}

	for _, key := range *undefine {
		delete(options, key)
	}

	suff := filepath.Ext(templPath)
	templatePaths := []string{templPath}
	for _, dir := range *searchDirs {
		entries, _ := os.ReadDir(dir)
		for _, entry := range entries {
			if !entry.IsDir() && strings.HasSuffix(entry.Name(), suff) {
				templatePaths = append(templatePaths, filepath.Join(dir, entry.Name()))
			}
		}
	}
	funcs := template.FuncMap{}
	funcs["default"] = defaultValue
	funcs["join"] = joinAny
	funcs["usepackage"] = usePackage

	var templ Template

	if *outputHTML {
		templ, err = htmltemplate.New("").Funcs(funcs).
			Delims("<<", ">>").
			ParseFiles(templatePaths...)
	} else {
		templ, err = template.New("").Funcs(funcs).
			Delims("<<", ">>").
			ParseFiles(templatePaths...)
	}
	if err != nil {
		log.Fatalln("unable to parse templates: ", err)
	}
	outFile := os.Stdout
	if *outputPath != "" {
		outFile, err = os.Create(*outputPath)
		if err != nil {
			log.Fatalf("unable to open `%s`: %v", *outputPath, err)
		}
	}
	defer outFile.Close()

	if err := templ.ExecuteTemplate(outFile, filepath.Base(templPath), options); err != nil {
		log.Fatalln("unable to execute template: ", err)
	}
}
