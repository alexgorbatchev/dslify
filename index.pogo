escodegen = require 'escodegen'
esprima = require 'esprima'

transform (func, dsl name: '_dsl', as string: false) =
    parsed = esprima.parse "(#(func.to string()))"
    rewrite identifiers under (parsed, dsl name)

    if (as string)
        escodegen.generate(parsed).replace(r/(^\s*\(|\);\s*$)/g, '')
    else
        func expression = parsed.body.0.expression
        params = param names in (func expression)
        js = escodegen.generate(func expression.body).replace(r/(^\s*\{|\}\s*$)/g, '')
        Function.apply(null, [dsl name].concat(params).concat(js))

exports.transform = transform

param names in (func expression) =
    params = []
    for each @(item) in (func expression.params)
        params.push (item.name)

    params

rewrite identifiers under (node, dsl name) =
    identifiers = identifiers under (node)
    for each @(identifier) in (identifiers)
        rewrite (identifier, dsl name)

identifiers under (node) =
    visit (node, scope) =
        if (!node || node.type == 'Property' || node == 'VariableDeclaration')
            return
        else
            add function arguments(node, scope)

            if (node.type == 'VariableDeclarator')
                scope.(node.id.name) = true
            else if (node.type == 'Identifier')
                node._scope = scope
                identifiers.push(node)
            else if (node :: Array)
                visit array (node, scope)
            else if (node :: Object)
                visit object (node, scope)

    visit array (node, scope) =
        for each @(item) in (node)
            visit (item, scope)

    visit object (node, scope) =
        for each @(key) in (Object.keys(node))
            if ((key != 'params') && (key != 'property'))
                visit (node.(key), scope)

    scope = {}
    identifiers = []
    visit (node, scope)
    identifiers

rewrite (identifier, dsl name) =
    scope = identifier._scope
    delete (identifier._scope)

    if (scope.(identifier.name))
        return

    identifier.type = 'MemberExpression'
    identifier.computed = false
    identifier.object = {
        type = 'Identifier'
        name = dsl name
    }
    identifier.property = {
        type = 'Identifier'
        name = identifier.name
    }
    delete (identifier.name)

add function arguments (node, parent scope) =
    if (node.type == 'FunctionExpression')
        param names = param names in (node)
        for each @(name) in (param names)
            parent scope.(name) = true
