"""Sample with style and maintainability issues"""

def CalculateTotal(items):
    """Function name should be snake_case"""
    total = 0
    for item in items:
        total += item['price']

    return total

MAX_limit = 100  # Should be MAX_LIMIT
MinValue = 10    # Should be MIN_VALUE

class MyClass:
    def __init__(self):
        self.DataValue = None  # Should be data_value

    def ProcessItems(self, InputData):
        """Both method and parameter names violate conventions"""
        TempResult = []  # Should be temp_result

        for Item in InputData:  # Loop variable should be lowercase
            if Item > 0:
                TempResult.append(Item)

        return TempResult
