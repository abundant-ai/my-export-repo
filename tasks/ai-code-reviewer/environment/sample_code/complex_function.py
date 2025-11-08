"""Sample with long and complex functions"""

def VeryLongComplexFunction(data, config, options, flags):
    """This function is way too long and complex"""
    result = []
    counter = 0

    # Process first batch
    for item in data:
        if item.get('type') == 'A':
            if item.get('status') == 'active':
                if item.get('priority') > 5:
                    if item.get('verified'):
                        result.append(item)
                        counter += 1

    # Process second batch
    for item in data:
        if item.get('type') == 'B':
            if item.get('status') == 'pending':
                result.append(item)

    # Process third batch
    for item in data:
        if item.get('type') == 'C':
            result.append(item)

    # Additional processing
    if config.get('enabled'):
        for r in result:
            r['processed'] = True

    # More processing
    if options.get('transform'):
        for r in result:
            r['transformed'] = True

    # Even more processing
    if flags.get('validate'):
        validated = []
        for r in result:
            if r.get('valid'):
                validated.append(r)
        result = validated

    # Final processing
    if flags.get('sort'):
        result = sorted(result, key=lambda x: x.get('priority', 0))

    # Calculate statistics
    total = len(result)
    active = sum(1 for r in result if r.get('status') == 'active')
    pending = sum(1 for r in result if r.get('status') == 'pending')

    # Return results with metadata
    return {
        'data': result,
        'total': total,
        'active': active,
        'pending': pending,
        'counter': counter
    }

class badClassName:
    """Class name should be PascalCase"""

    def BadMethod(self):
        """Method name should be snake_case"""
        pass
